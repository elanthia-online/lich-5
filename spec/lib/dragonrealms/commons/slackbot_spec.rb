# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'

# Load production code
require File.join(LIB_DIR, 'dragonrealms', 'commons', 'slackbot.rb')

RSpec.describe Lich::DragonRealms::SlackBot do
  let(:lnet_buffer) { [] }
  let(:lnet_script) do
    script = double('lnet_script')
    allow(script).to receive(:name).and_return('lnet')
    allow(script).to receive(:unique_buffer).and_return(lnet_buffer)
    script
  end

  let(:mock_http) do
    http = double('Net::HTTP')
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:verify_mode=)
    allow(http).to receive(:request).and_return(success_response)
    http
  end

  let(:success_response) do
    resp = double('Net::HTTPSuccess')
    allow(resp).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    allow(resp).to receive(:code).and_return('200')
    allow(resp).to receive(:body).and_return('{"ok":true}')
    resp
  end

  let(:auth_success_response) do
    resp = double('Net::HTTPSuccess')
    allow(resp).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    allow(resp).to receive(:code).and_return('200')
    allow(resp).to receive(:body).and_return('{"ok":true}')
    resp
  end

  let(:users_list_response) do
    resp = double('Net::HTTPSuccess')
    allow(resp).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    allow(resp).to receive(:code).and_return('200')
    members = [{ 'name' => 'testuser', 'id' => 'U12345' }]
    allow(resp).to receive(:body).and_return({ 'ok' => true, 'members' => members }.to_json)
    resp
  end

  before(:each) do
    allow(Net::HTTP).to receive(:new).and_return(mock_http)
    allow(Net::HTTP::Post).to receive(:new).and_return(double('req', set_form_data: nil))
    allow(Lich).to receive(:log)
    allow(Lich::Messaging).to receive(:msg)
    allow(XMLData).to receive(:game).and_return('DR')
  end

  after(:each) do
    UserVars.slack_token = nil
  end

  # Helper: build a bot with valid token and users list, skipping cache
  def build_initialized_bot
    UserVars.slack_token = 'valid-token'
    call_count = 0
    allow(mock_http).to receive(:request) do
      call_count += 1
      call_count == 1 ? auth_success_response : users_list_response
    end
    described_class.new
  end

  # ---- Constants ----

  describe 'constants' do
    it 'defines API_URL' do
      expect(described_class::API_URL).to eq('https://slack.com/api/')
    end

    it 'defines MAX_NETWORK_RETRIES' do
      expect(described_class::MAX_NETWORK_RETRIES).to eq(5)
    end

    it 'defines MAX_RETRY_DELAY_SECONDS' do
      expect(described_class::MAX_RETRY_DELAY_SECONDS).to eq(300)
    end

    it 'defines USERS_CACHE_TTL' do
      expect(described_class::USERS_CACHE_TTL).to eq(3600)
    end

    it 'defines USERS_CACHE_SCRIPT' do
      expect(described_class::USERS_CACHE_SCRIPT).to eq('_slackbot_users_cache')
    end
  end

  # ---- Error Classes ----

  describe 'error classes' do
    it 'ThrottlingError inherits from ApiError' do
      expect(described_class::ThrottlingError.superclass).to eq(described_class::ApiError)
    end

    it 'ThrottlingError stores retry_after' do
      err = described_class::ThrottlingError.new('throttled', 30)
      expect(err.retry_after).to eq(30)
    end

    it 'ThrottlingError retry_after defaults to nil' do
      err = described_class::ThrottlingError.new('throttled')
      expect(err.retry_after).to be_nil
    end
  end

  # ---- #initialize ----

  describe '#initialize' do
    context 'when slack_token is already authed' do
      it 'initializes successfully without starting lnet' do
        expect(Script).not_to receive(:exists?)
        bot = build_initialized_bot
        expect(bot.initialized?).to be true
        expect(bot.error_message).to be_nil
      end
    end

    context 'when token is nil and lnet.lic does not exist' do
      before { allow(Script).to receive(:exists?).with('lnet').and_return(false) }

      it 'sets error_message and does not initialize' do
        bot = described_class.new
        expect(bot.initialized?).to be false
        expect(bot.error_message).to include('lnet.lic not found')
      end
    end

    context 'when lnet does not connect within timeout' do
      before do
        allow(Script).to receive(:exists?).with('lnet').and_return(true)
        allow(Script).to receive(:running?).with('lnet').and_return(false)
        start = Time.now
        call_count = 0
        allow(Time).to receive(:now) do
          call_count += 1
          start + (call_count * 31)
        end
      end

      it 'sets error_message about timeout' do
        bot = described_class.new
        expect(bot.initialized?).to be false
        expect(bot.error_message).to include('did not connect within')
      end
    end

    context 'when users cache exists' do
      before do
        UserVars.slack_token = 'valid-token'
        allow(mock_http).to receive(:request).and_return(auth_success_response)
        Lich::Common::DB_Store.store_data(
          'DR', '_slackbot_users_cache',
          { 'members' => [{ 'name' => 'cached_user', 'id' => 'U99999' }], 'fetched_at' => Time.now.to_i }
        )
      end

      it 'uses cached users list instead of calling the API' do
        bot = described_class.new
        expect(bot.initialized?).to be true
        channel = bot.send(:get_dm_channel, 'cached_user')
        expect(channel).to eq('U99999')
      end
    end
  end

  # ---- #reconnect! ----

  describe '#reconnect!' do
    it 'resets error state and re-initializes' do
      allow(Script).to receive(:exists?).with('lnet').and_return(false)
      bot = described_class.new
      expect(bot.initialized?).to be false

      UserVars.slack_token = 'valid-token'
      call_count = 0
      allow(mock_http).to receive(:request) do
        call_count += 1
        call_count == 1 ? auth_success_response : users_list_response
      end

      bot.reconnect!
      expect(bot.initialized?).to be true
      expect(bot.error_message).to be_nil
    end

    it 'returns false if reconnection fails' do
      allow(Script).to receive(:exists?).with('lnet').and_return(false)
      bot = described_class.new
      result = bot.reconnect!
      expect(result).to be false
    end
  end

  # ---- #direct_message ----

  describe '#direct_message' do
    context 'when username is nil' do
      it 'returns nil without attempting API call' do
        bot = build_initialized_bot
        result = bot.direct_message(nil, 'hello')
        expect(result).to be_nil
      end
    end

    context 'when username is whitespace only' do
      it 'returns nil' do
        bot = build_initialized_bot
        result = bot.direct_message('   ', 'hello')
        expect(result).to be_nil
      end
    end

    context 'when user not found in users_list' do
      it 'returns nil with error message' do
        bot = build_initialized_bot
        expect(Lich::Messaging).to receive(:msg).with('bold', /user 'unknown' not found/)
        result = bot.direct_message('unknown', 'hello')
        expect(result).to be_nil
      end
    end

    context 'when bot is not initialized' do
      it 'attempts reconnect before sending' do
        allow(Script).to receive(:exists?).with('lnet').and_return(false)
        bot = described_class.new
        expect(bot).to receive(:reconnect!)
        bot.direct_message('testuser', 'hello')
      end
    end

    context 'when reconnect fails' do
      it 'returns nil with not-connected message' do
        allow(Script).to receive(:exists?).with('lnet').and_return(false)
        bot = described_class.new
        expect(Lich::Messaging).to receive(:msg).with('bold', /not connected/)
        bot.direct_message('testuser', 'hello')
      end
    end

    context 'when post raises an Error' do
      it 'logs and messages instead of crashing' do
        bot = build_initialized_bot
        allow(mock_http).to receive(:request) do
          raise described_class::ApiError, 'test error'
        end
        expect(Lich).to receive(:log).with(/Failed to send Slack message/)
        expect { bot.direct_message('testuser', 'hello') }.not_to raise_error
      end
    end
  end

  # ---- Users Cache ----

  describe 'users cache' do
    let!(:bot) { build_initialized_bot }

    describe '#read_users_cache' do
      it 'returns nil when cache is empty' do
        Lich::Common::DB_Store.reset!
        expect(bot.send(:read_users_cache)).to be_nil
      end

      it 'returns nil when cache has no fetched_at' do
        Lich::Common::DB_Store.store_data('DR', '_slackbot_users_cache', { 'members' => [] })
        expect(bot.send(:read_users_cache)).to be_nil
      end

      it 'returns nil when cache is expired' do
        Lich::Common::DB_Store.store_data(
          'DR', '_slackbot_users_cache',
          { 'members' => [{ 'name' => 'old', 'id' => 'U1' }], 'fetched_at' => Time.now.to_i - 7200 }
        )
        expect(bot.send(:read_users_cache)).to be_nil
      end

      it 'returns data when cache is fresh' do
        members = [{ 'name' => 'fresh', 'id' => 'U2' }]
        Lich::Common::DB_Store.store_data(
          'DR', '_slackbot_users_cache',
          { 'members' => members, 'fetched_at' => Time.now.to_i - 60 }
        )
        cached = bot.send(:read_users_cache)
        expect(cached['members']).to eq(members)
      end

      it 'uses XMLData.game for scope isolation' do
        allow(XMLData).to receive(:game).and_return('GS')
        Lich::Common::DB_Store.store_data(
          'DR', '_slackbot_users_cache',
          { 'members' => [{ 'name' => 'dr_user', 'id' => 'U1' }], 'fetched_at' => Time.now.to_i }
        )
        expect(bot.send(:read_users_cache)).to be_nil
      end
    end

    describe '#write_users_cache' do
      it 'stores members with timestamp' do
        members = [{ 'name' => 'new', 'id' => 'U3' }]
        bot.send(:write_users_cache, members)

        cached = Lich::Common::DB_Store.get_data('DR', '_slackbot_users_cache')
        expect(cached['members']).to eq(members)
        expect(cached['fetched_at']).to be_within(2).of(Time.now.to_i)
      end
    end
  end

  # ---- #fetch_users_list ----

  describe '#fetch_users_list' do
    it 'uses cache when available and skips API' do
      members = [{ 'name' => 'cached', 'id' => 'U100' }]
      Lich::Common::DB_Store.store_data(
        'DR', '_slackbot_users_cache',
        { 'members' => members, 'fetched_at' => Time.now.to_i }
      )

      UserVars.slack_token = 'valid-token'
      allow(mock_http).to receive(:request).and_return(auth_success_response)

      bot = described_class.new
      expect(bot.send(:get_dm_channel, 'cached')).to eq('U100')
    end

    it 'writes cache after successful API fetch' do
      UserVars.slack_token = 'valid-token'
      call_count = 0
      allow(mock_http).to receive(:request) do
        call_count += 1
        call_count == 1 ? auth_success_response : users_list_response
      end

      described_class.new

      cached = Lich::Common::DB_Store.get_data('DR', '_slackbot_users_cache')
      expect(cached['members']).to include({ 'name' => 'testuser', 'id' => 'U12345' })
    end

    it 'does not write cache when API returns empty members' do
      UserVars.slack_token = 'valid-token'
      empty_resp = double('resp')
      allow(empty_resp).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(empty_resp).to receive(:code).and_return('200')
      allow(empty_resp).to receive(:body).and_return({ 'ok' => true, 'members' => [] }.to_json)

      call_count = 0
      allow(mock_http).to receive(:request) do
        call_count += 1
        call_count == 1 ? auth_success_response : empty_resp
      end

      described_class.new

      cached = Lich::Common::DB_Store.get_data('DR', '_slackbot_users_cache')
      expect(cached).to be_empty
    end
  end

  # ---- #fetch_users_from_api ----

  describe '#fetch_users_from_api' do
    let!(:bot) { build_initialized_bot }

    context 'when throttled and another character cached' do
      it 'returns cached data instead of retrying' do
        throttle_resp = double('resp_429')
        allow(throttle_resp).to receive(:code).and_return('429')
        allow(throttle_resp).to receive(:[]).with('Retry-After').and_return('30')

        allow(mock_http).to receive(:request).and_return(throttle_resp)

        members = [{ 'name' => 'other_char_cached', 'id' => 'U777' }]
        Lich::Common::DB_Store.store_data(
          'DR', '_slackbot_users_cache',
          { 'members' => members, 'fetched_at' => Time.now.to_i }
        )

        result = bot.send(:fetch_users_from_api)
        expect(result['members'].first['name']).to eq('other_char_cached')
      end
    end

    context 'when throttled with no cache available' do
      it 'retries with backoff' do
        Lich::Common::DB_Store.reset!

        throttle_resp = double('resp_429')
        allow(throttle_resp).to receive(:code).and_return('429')
        allow(throttle_resp).to receive(:[]).with('Retry-After').and_return('1')

        ok_resp = double('resp_ok')
        allow(ok_resp).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(ok_resp).to receive(:code).and_return('200')
        allow(ok_resp).to receive(:body).and_return({ 'ok' => true, 'members' => [{ 'name' => 'retry_user', 'id' => 'U888' }] }.to_json)

        call_count = 0
        allow(mock_http).to receive(:request) do
          call_count += 1
          call_count <= 2 ? throttle_resp : ok_resp
        end
        allow(bot).to receive(:sleep)

        result = bot.send(:fetch_users_from_api)
        expect(result['members'].first['name']).to eq('retry_user')
      end
    end

    context 'when API error occurs' do
      it 'returns empty members list' do
        allow(mock_http).to receive(:request) do
          raise described_class::ApiError, 'invalid_auth'
        end

        result = bot.send(:fetch_users_from_api)
        expect(result['members']).to eq([])
      end
    end

    context 'when network error occurs' do
      it 'returns empty members list after retries exhaust' do
        allow(mock_http).to receive(:request).and_raise(Timeout::Error)
        allow(bot).to receive(:sleep)

        result = bot.send(:fetch_users_from_api)
        expect(result['members']).to eq([])
      end
    end
  end

  # ---- #post ----

  describe '#post (via send)' do
    let!(:bot) { build_initialized_bot }

    context 'successful request' do
      it 'returns parsed JSON body' do
        resp = double('resp')
        allow(resp).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(resp).to receive(:code).and_return('200')
        allow(resp).to receive(:body).and_return('{"ok":true,"data":"test"}')
        allow(mock_http).to receive(:request).and_return(resp)

        result = bot.send(:post, 'test.method', { 'token' => 'test' })
        expect(result).to eq({ 'ok' => true, 'data' => 'test' })
      end
    end

    context 'HTTP 429 throttling' do
      it 'raises ThrottlingError with retry_after' do
        throttle_resp = double('resp_429')
        allow(throttle_resp).to receive(:code).and_return('429')
        allow(throttle_resp).to receive(:[]).with('Retry-After').and_return('45')
        allow(mock_http).to receive(:request).and_return(throttle_resp)

        expect {
          bot.send(:post, 'test.method', { 'token' => 'test' })
        }.to raise_error(described_class::ThrottlingError) { |e|
          expect(e.retry_after).to eq(45)
        }
      end

      it 'raises ThrottlingError with nil retry_after when header missing' do
        throttle_resp = double('resp_429')
        allow(throttle_resp).to receive(:code).and_return('429')
        allow(throttle_resp).to receive(:[]).with('Retry-After').and_return(nil)
        allow(mock_http).to receive(:request).and_return(throttle_resp)

        expect {
          bot.send(:post, 'test.method', { 'token' => 'test' })
        }.to raise_error(described_class::ThrottlingError) { |e|
          expect(e.retry_after).to be_nil
        }
      end
    end

    context 'network error with retry' do
      it 'retries and succeeds' do
        ok_resp = double('resp_ok')
        allow(ok_resp).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(ok_resp).to receive(:code).and_return('200')
        allow(ok_resp).to receive(:body).and_return('{"ok":true}')

        call_count = 0
        allow(mock_http).to receive(:request) do
          call_count += 1
          raise Timeout::Error, 'connection timed out' if call_count == 1

          ok_resp
        end
        allow(bot).to receive(:sleep)

        result = bot.send(:post, 'test.method', { 'token' => 'test' })
        expect(result['ok']).to be true
      end
    end

    context 'network error exceeds max retries' do
      it 'raises NetworkError' do
        allow(mock_http).to receive(:request).and_raise(SocketError)
        allow(bot).to receive(:sleep)

        expect {
          bot.send(:post, 'test.method', { 'token' => 'test' })
        }.to raise_error(described_class::NetworkError, /Network error after 5 retries/)
      end
    end

    context 'JSON parse error' do
      it 'raises ApiError' do
        resp = double('resp')
        allow(resp).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(resp).to receive(:code).and_return('200')
        allow(resp).to receive(:body).and_return('not json')
        allow(mock_http).to receive(:request).and_return(resp)

        expect {
          bot.send(:post, 'test.method', { 'token' => 'test' })
        }.to raise_error(described_class::ApiError, /Failed to parse/)
      end
    end

    context 'Slack API error (ok: false)' do
      it 'raises ApiError with error code' do
        resp = double('resp')
        allow(resp).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(resp).to receive(:code).and_return('200')
        allow(resp).to receive(:body).and_return('{"ok":false,"error":"invalid_auth"}')
        allow(mock_http).to receive(:request).and_return(resp)

        expect {
          bot.send(:post, 'test.method', { 'token' => 'test' })
        }.to raise_error(described_class::ApiError, /invalid_auth/)
      end
    end
  end

  # ---- Boundary / Adversarial ----

  describe 'boundary and adversarial cases' do
    describe 'cache TTL boundary' do
      let!(:bot) { build_initialized_bot }

      it 'accepts cache at exactly TTL - 1 second' do
        Lich::Common::DB_Store.store_data(
          'DR', '_slackbot_users_cache',
          { 'members' => [{ 'name' => 'edge', 'id' => 'U1' }], 'fetched_at' => Time.now.to_i - 3599 }
        )
        expect(bot.send(:read_users_cache)).not_to be_nil
      end

      it 'rejects cache at TTL + 1 second' do
        Lich::Common::DB_Store.store_data(
          'DR', '_slackbot_users_cache',
          { 'members' => [{ 'name' => 'edge', 'id' => 'U1' }], 'fetched_at' => Time.now.to_i - 3601 }
        )
        expect(bot.send(:read_users_cache)).to be_nil
      end
    end

    describe 'cache with corrupted data' do
      let!(:bot) { build_initialized_bot }

      it 'returns nil when fetched_at is nil' do
        Lich::Common::DB_Store.store_data(
          'DR', '_slackbot_users_cache',
          { 'members' => [], 'fetched_at' => nil }
        )
        expect(bot.send(:read_users_cache)).to be_nil
      end

      it 'returns nil when data is nil' do
        Lich::Common::DB_Store.reset!
        allow(Lich::Common::DB_Store).to receive(:get_data).and_return(nil)
        expect(bot.send(:read_users_cache)).to be_nil
      end
    end

    describe 'thundering herd scenario' do
      it 'second bot uses cache populated by first bot' do
        UserVars.slack_token = 'valid-token'
        call_count = 0
        allow(mock_http).to receive(:request) do
          call_count += 1
          call_count == 1 ? auth_success_response : users_list_response
        end

        # First bot fetches from API and caches
        bot1 = described_class.new
        expect(bot1.initialized?).to be true

        # Second bot should use cache
        expect(mock_http).not_to receive(:request).with(
          having_attributes(path: '/api/users.list')
        )

        call_count = 0
        allow(mock_http).to receive(:request).and_return(auth_success_response)

        bot2 = described_class.new
        expect(bot2.initialized?).to be true
        expect(bot2.send(:get_dm_channel, 'testuser')).to eq('U12345')
      end
    end

    describe 'network retry jitter' do
      let!(:bot) { build_initialized_bot }

      it 'does not sleep for negative delay' do
        allow(mock_http).to receive(:request).and_raise(Errno::ECONNRESET)
        delays = []
        allow(bot).to receive(:sleep) { |d| delays << d }

        expect {
          bot.send(:post, 'test.method', { 'token' => 'test' })
        }.to raise_error(described_class::NetworkError)

        delays.each { |d| expect(d).to be >= 0 }
      end
    end

    describe '#authed? with edge cases' do
      let!(:bot) { build_initialized_bot }

      it 'returns false for nil token' do
        expect(bot.authed?(nil)).to be false
      end

      it 'treats empty string as truthy and hits API' do
        allow(mock_http).to receive(:request).and_return(auth_success_response)
        expect(bot.authed?('')).to be true
      end
    end

    describe '#get_dm_channel with edge cases' do
      let!(:bot) { build_initialized_bot }

      it 'returns nil when members is nil' do
        bot.instance_variable_set(:@users_list, { 'members' => nil })
        expect(bot.send(:get_dm_channel, 'testuser')).to be_nil
      end

      it 'returns nil when members is empty' do
        bot.instance_variable_set(:@users_list, { 'members' => [] })
        expect(bot.send(:get_dm_channel, 'testuser')).to be_nil
      end
    end

    describe 'reconnect! clears stale error_message' do
      it 'clears the previous error when reconnecting' do
        allow(Script).to receive(:exists?).with('lnet').and_return(false)
        bot = described_class.new
        expect(bot.error_message).to include('lnet.lic not found')

        UserVars.slack_token = 'valid-token'
        call_count = 0
        allow(mock_http).to receive(:request) do
          call_count += 1
          call_count == 1 ? auth_success_response : users_list_response
        end

        bot.reconnect!
        expect(bot.error_message).to be_nil
      end
    end

    describe 'direct_message lazy reconnect does not loop' do
      it 'only attempts reconnect once per call' do
        allow(Script).to receive(:exists?).with('lnet').and_return(false)
        bot = described_class.new

        reconnect_count = 0
        allow(bot).to receive(:reconnect!) do
          reconnect_count += 1
          false
        end

        bot.direct_message('testuser', 'hello')
        expect(reconnect_count).to eq(1)
      end
    end
  end

  # ---- #lnet_connected? ----

  describe '#lnet_connected?' do
    let!(:bot) { build_initialized_bot }

    context 'when LNet.server is nil' do
      before do
        stub_const('LNet', Module.new)
        allow(LNet).to receive(:server).and_return(nil)
      end

      it 'returns false' do
        expect(bot.lnet_connected?).to be false
      end
    end

    context 'when LNet.server is closed' do
      before do
        stub_const('LNet', Module.new)
        allow(LNet).to receive(:server).and_return(double('server', closed?: true))
      end

      it 'returns false' do
        expect(bot.lnet_connected?).to be false
      end
    end

    context 'when LNet.last_recv is stale' do
      before do
        stub_const('LNet', Module.new)
        allow(LNet).to receive(:server).and_return(double('server', closed?: false))
        allow(LNet).to receive(:respond_to?).and_call_original
        allow(LNet).to receive(:respond_to?).with(:last_recv).and_return(true)
        allow(LNet).to receive(:last_recv).and_return(Time.now - 300)
      end

      it 'returns false' do
        expect(bot.lnet_connected?).to be false
      end
    end

    context 'when IOError occurs' do
      before do
        stub_const('LNet', Module.new)
        allow(LNet).to receive(:server).and_raise(IOError)
      end

      it 'returns false' do
        expect(bot.lnet_connected?).to be false
      end
    end
  end

  # ---- #request_token ----

  describe '#request_token (via send)' do
    let(:bot) do
      instance = build_initialized_bot
      instance.instance_variable_set(:@lnet, lnet_script)
      instance
    end

    context 'when token is received' do
      it 'returns the token string' do
        line = '[Private]-MAHTRA:Quilsilgas: "slack_token: xoxb-real-token"'
        allow(bot).to receive(:get).and_return(line)
        allow(bot).to receive(:pause)

        result = bot.send(:request_token, 'Quilsilgas')
        expect(result).to eq('xoxb-real-token')
      end
    end

    context 'when Not Found response' do
      it 'returns false' do
        line = '[Private]-MAHTRA:Quilsilgas: "slack_token: Not Found"'
        allow(bot).to receive(:get).and_return(line)
        allow(bot).to receive(:pause)

        result = bot.send(:request_token, 'Quilsilgas')
        expect(result).to be false
      end
    end

    context 'when lnet not available' do
      it 'returns false without crashing' do
        bot.instance_variable_set(:@lnet, nil)
        result = bot.send(:request_token, 'Quilsilgas')
        expect(result).to be false
      end
    end
  end
end
