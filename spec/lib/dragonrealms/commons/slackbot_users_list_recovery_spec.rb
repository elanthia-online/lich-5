# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'

require File.join(LIB_DIR, 'dragonrealms', 'commons', 'slackbot.rb')

# Exercises users.list failure and recovery through the real SlackBot code:
# real Net::HTTP and Net::HTTP::Post objects, real response classes, real
# retry and cache logic. Only the transport (Net::HTTP#start and #request), SlackBot#sleep
# (which moves the monotonic clock forward instead of waiting) and the
# in-memory DB_Store mock from spec_helper stand in for the outside world.
RSpec.describe Lich::DragonRealms::SlackBot, 'users.list failure recovery' do
  let(:alice) { { 'name' => 'alice', 'id' => 'U1' } }
  let(:members) { [alice] }

  # Scripted responses per API method. Each entry is a Proc returning a
  # Net::HTTPResponse or raising. The last entry repeats forever.
  let(:plan) { Hash.new { |h, k| h[k] = [] } }
  let(:calls) { Hash.new(0) }
  let(:posted) { [] }
  let(:sleeps) { [] }
  let(:messages) { [] }
  let(:clock) { { offset: 0.0 } }
  # The documented in-send cap per Slack API step (SlackBot::SEND_REQUEST_BUDGET).
  let(:send_budget) { 5 }

  def http_response(code, body = '', headers = {})
    res = Net::HTTPResponse::CODE_TO_OBJ.fetch(code.to_s).new('1.1', code.to_s, 'msg')
    headers.each { |k, v| res[k] = v }
    res.instance_variable_set(:@body, body)
    res.instance_variable_set(:@read, true)
    res
  end

  def ok(body)
    -> { http_response(200, body.merge('ok' => true).to_json) }
  end

  def users_ok
    ok('members' => members)
  end

  def failure(kind)
    case kind
    when :http500 then -> { http_response(500, '') }
    when :ok_false then -> { http_response(200, { 'ok' => false, 'error' => 'internal_error' }.to_json) }
    when :econnreset then -> { raise Errno::ECONNRESET }
    when :throttle then -> { http_response(429, '', 'Retry-After' => '1') }
    when :throttle_long then -> { http_response(429, '', 'Retry-After' => '30') }
    when :throttle_zero then -> { http_response(429, '', 'Retry-After' => '0') }
    when :econnrefused then -> { raise Errno::ECONNREFUSED }
    end
  end

  def fresh_cache(list = members)
    Lich::Common::DB_Store.store_data('DR', '_slackbot_users_cache', { 'members' => list, 'fetched_at' => Time.now.to_i })
  end

  def cache
    Lich::Common::DB_Store.get_data('DR', '_slackbot_users_cache')
  end

  # Moves the monotonic clock forward without running any SlackBot code.
  def advance(seconds)
    clock[:offset] += seconds
  end

  # Lets the post-failure users.list cooldown (SlackBot::USERS_LIST_RETRY_COOLDOWN, 30 s) run out.
  def wait_out_cooldown
    advance(31)
  end

  # Seconds spent in SlackBot#sleep and transport calls made during one block.
  def measure
    start = clock[:offset]
    before = calls.dup
    result = yield
    [result, clock[:offset] - start, calls.to_h { |k, v| [k, v - before[k]] }]
  end

  before do
    UserVars.slack_token = 'valid-token'
    allow(XMLData).to receive(:game).and_return('DR')
    allow(Lich).to receive(:log)
    allow(Lich::Messaging).to receive(:msg) { |_type, text| messages << text }

    # The send path opens the connection itself (SlackBot#request_before);
    # keep it off the network. The connection stays "not started", so
    # request_before has nothing to close.
    allow_any_instance_of(Net::HTTP).to receive(:start) { |http| http }
    allow_any_instance_of(Net::HTTP).to receive(:request) do |_http, req|
      method = req.path.sub('/api/', '')
      calls[method] += 1
      posted << URI.decode_www_form(req.body).to_h if method == 'chat.postMessage'
      queue = plan[method]
      raise "unplanned call to #{method}" if queue.empty?

      (queue.length > 1 ? queue.shift : queue.first).call
    end

    allow(Process).to receive(:clock_gettime).and_wrap_original do |original, id, *rest|
      value = original.call(id, *rest)
      id == Process::CLOCK_MONOTONIC && rest.empty? ? value + clock[:offset] : value
    end
    allow_any_instance_of(described_class).to receive(:sleep) do |_bot, seconds|
      sleeps << seconds
      clock[:offset] += seconds
    end

    plan['auth.test'] << ok({})
    plan['chat.postMessage'] << ok('ts' => '1')
  end

  after do
    UserVars.slack_token = nil
  end

  # Number of users.list attempts each failure shape takes under the full
  # (startup) retry policy before the bot gives up.
  startup_attempts = { http500: 1, ok_false: 1, econnreset: 6, throttle: 11 }
  startup_attempts.each do |kind, attempts|
    context "when users.list fails at startup (#{kind})" do
      before do
        attempts.times { plan['users.list'] << failure(kind) }
        plan['users.list'] << users_ok
      end

      it 'does not mark the bot initialized and records why' do
        bot = described_class.new

        expect(calls['users.list']).to eq(attempts)
        expect(bot.initialized?).to be false
        expect(bot.error_message).to eq('Slack user list unavailable')
        expect(cache).to be_empty
      end

      it 'loads the list and delivers on the next message, without re-checking the token' do
        bot = described_class.new
        wait_out_cooldown

        result, = measure { bot.direct_message('alice', 'help') }

        expect(result).to include('ok' => true)
        expect(bot.initialized?).to be true
        expect(bot.error_message).to be_nil
        expect(posted.map { |p| p['channel'] }).to eq(['U1'])
        expect(calls['users.list']).to eq(attempts + 1)
        expect(calls['auth.test']).to eq(1)
        expect(cache['members']).to eq(members)
      end

      it 'delivers from a cache another process refilled, with no further users.list call' do
        bot = described_class.new
        plan['users.list'].clear
        plan['users.list'] << failure(kind)
        fresh_cache

        result, _elapsed, delta = measure { bot.direct_message('alice', 'help') }

        expect(result).to include('ok' => true)
        expect(delta['users.list']).to eq(0)
        expect(posted.map { |p| p['channel'] }).to eq(['U1'])
      end
    end
  end

  describe 'a message sent while users.list is still failing' do
    {
      http500: 1, ok_false: 1, econnreset: 1, throttle_long: 1,
      throttle: 5 # Retry-After 1: four 1 s waits fit in the 5 s budget
    }.each do |kind, send_attempts|
      it "gives up within the send budget (#{kind})" do
        plan['users.list'] << failure(kind)
        bot = described_class.new
        wait_out_cooldown
        sleeps.clear

        result, elapsed, delta = measure { bot.direct_message('alice', 'help') }

        expect(result).to be_nil
        expect(elapsed).to be < send_budget
        expect(delta['users.list']).to eq(send_attempts)
        expect(delta['auth.test']).to eq(0)
        expect(posted).to be_empty
        expect(bot.initialized?).to be false
        expect(messages.last).to match(/not connected/)
      end
    end

    it 'makes no new users.list call during the cooldown after a failure' do
      plan['users.list'] << failure(:http500)
      bot = described_class.new

      3.times { bot.direct_message('alice', 'help') }
      expect(calls['users.list']).to eq(1)

      advance(29)
      bot.direct_message('alice', 'help')
      expect(calls['users.list']).to eq(1)

      advance(2)
      bot.direct_message('alice', 'help')
      expect(calls['users.list']).to eq(2)
      expect(posted).to be_empty
    end

    it 'waits out a Retry-After longer than the cooldown before calling again' do
      plan['users.list'] << -> { http_response(429, '', 'Retry-After' => '120') }
      bot = described_class.new
      expect(calls['users.list']).to eq(11)

      plan['users.list'].clear
      plan['users.list'] << users_ok
      advance(60)
      expect(bot.direct_message('alice', 'help')).to be_nil
      expect(calls['users.list']).to eq(11)

      advance(61)
      expect(bot.direct_message('alice', 'help')).to include('ok' => true)
      expect(calls['users.list']).to eq(12)
    end

    it 'caps the cooldown at MAX_RETRY_DELAY_SECONDS when Retry-After is outsized' do
      plan['users.list'] << -> { http_response(429, '', 'Retry-After' => '7200') }
      bot = described_class.new
      expect(calls['users.list']).to eq(11)

      plan['users.list'].clear
      plan['users.list'] << users_ok
      advance(299)
      expect(bot.direct_message('alice', 'help')).to be_nil
      expect(calls['users.list']).to eq(11)

      advance(2)
      expect(bot.direct_message('alice', 'help')).to include('ok' => true)
      expect(calls['users.list']).to eq(12)
    end

    it 'caps the cooldown when a Retry-After overruns the send budget' do
      plan['users.list'] << failure(:http500)
      bot = described_class.new
      wait_out_cooldown
      plan['users.list'].clear
      plan['users.list'] << -> { http_response(429, '', 'Retry-After' => '7200') }
      expect(bot.direct_message('alice', 'help')).to be_nil
      expect(calls['users.list']).to eq(2)

      plan['users.list'].clear
      plan['users.list'] << users_ok
      advance(299)
      expect(bot.direct_message('alice', 'help')).to be_nil
      expect(calls['users.list']).to eq(2)

      advance(2)
      expect(bot.direct_message('alice', 'help')).to include('ok' => true)
      expect(calls['users.list']).to eq(3)
    end

    # The throttle backoff jitter is pinned to its maximum (Retry-After 30
    # gives a 45 s backoff; no Retry-After gives 2 s), so a cooldown taken
    # from the backoff instead of Retry-After would show up here.
    [['30', 'a Retry-After of 30'], [nil, 'no Retry-After']].each do |retry_after, label|
      it "sets the cooldown from Retry-After, not the jittered backoff, after a throttled send (#{label})" do
        allow_any_instance_of(described_class).to receive(:rand) { |_bot, range| range.max }
        plan['users.list'] << failure(:http500)
        bot = described_class.new
        wait_out_cooldown
        plan['users.list'].clear
        plan['users.list'] << -> { http_response(429, '', retry_after ? { 'Retry-After' => retry_after } : {}) }
        expect(bot.direct_message('alice', 'help')).to be_nil
        throttled_calls = calls['users.list']

        plan['users.list'].clear
        plan['users.list'] << users_ok
        advance(29)
        expect(bot.direct_message('alice', 'help')).to be_nil
        expect(calls['users.list']).to eq(throttled_calls)

        advance(2)
        expect(bot.direct_message('alice', 'help')).to include('ok' => true)
        expect(calls['users.list']).to eq(throttled_calls + 1)
      end
    end

    it 'does not let an unexpected transport error escape the message call' do
      plan['users.list'] << failure(:http500)
      bot = described_class.new
      wait_out_cooldown
      plan['users.list'].clear
      plan['users.list'] << -> { raise Errno::ECONNREFUSED }

      result = nil
      expect { result = bot.direct_message('alice', 'help') }.not_to raise_error
      expect(result).to be_nil
      expect(bot.initialized?).to be false
      expect(bot.error_message).to include('Connection refused')
    end

    it 'starts the cooldown after an unexpected transport error from users.list' do
      plan['users.list'] << failure(:http500)
      bot = described_class.new
      wait_out_cooldown
      plan['users.list'].clear
      plan['users.list'] << failure(:econnrefused)
      bot.direct_message('alice', 'help')
      expect(calls['users.list']).to eq(2)

      plan['users.list'].clear
      plan['users.list'] << users_ok
      advance(29)
      expect(bot.direct_message('alice', 'help')).to be_nil
      expect(calls['users.list']).to eq(2)

      advance(2)
      expect(bot.direct_message('alice', 'help')).to include('ok' => true)
      expect(calls['users.list']).to eq(3)
    end

    it 'waits at least 1 s between calls when Retry-After is 0' do
      plan['users.list'] << failure(:http500)
      bot = described_class.new
      wait_out_cooldown
      plan['users.list'].clear
      plan['users.list'] << failure(:throttle_zero)
      sleeps.clear

      result, elapsed, delta = measure { bot.direct_message('alice', 'help') }

      expect(result).to be_nil
      expect(elapsed).to be < send_budget
      expect(sleeps).to all(be >= 1)
      expect(delta['users.list']).to eq(sleeps.length + 1)
      expect(delta['users.list']).to be <= send_budget
    end

    it 'still delivers from a refilled cache during the cooldown' do
      plan['users.list'] << failure(:http500)
      bot = described_class.new
      fresh_cache

      expect(bot.direct_message('alice', 'help')).to include('ok' => true)
      expect(calls['users.list']).to eq(1)
    end

    it 'skips the startup jitter sleep' do
      plan['users.list'] << failure(:http500)
      bot = described_class.new
      wait_out_cooldown
      sleeps.clear

      bot.direct_message('alice', 'help')

      expect(sleeps).to be_empty
    end

    it 'abandons a hung request at the deadline' do
      plan['users.list'] << failure(:http500)
      bot = described_class.new
      wait_out_cooldown
      stub_const("#{described_class}::SEND_REQUEST_BUDGET", 0.2)
      plan['users.list'].clear
      plan['users.list'] << -> { Kernel.sleep(5) }

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = bot.direct_message('alice', 'help')
      wall = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      expect(result).to be_nil
      expect(wall).to be < 2
      expect(bot.initialized?).to be false
    end
  end

  describe 'a startup throttled with an unusable Retry-After' do
    it 'waits at least 1 s between the retries when Retry-After is 0' do
      plan['users.list'] << failure(:throttle_zero)

      bot = described_class.new

      expect(bot.initialized?).to be false
      expect(calls['users.list']).to eq(11)
      throttle_waits = sleeps.drop(1) # the first sleep is the startup jitter
      expect(throttle_waits.length).to eq(10)
      expect(throttle_waits).to all(be >= 1)
    end

    it 'falls back to the exponential backoff when Retry-After is not a number' do
      plan['users.list'] << -> { http_response(429, '', 'Retry-After' => 'soon') }
      plan['users.list'] << users_ok

      bot = described_class.new

      expect(bot.initialized?).to be true
      expect(sleeps.drop(1).first).to be >= 30
    end
  end

  describe 'a bot whose token was never verified' do
    # Startup leaves the bot unverified: auth.test answers ok: false and
    # lnet.lic is not installed, so no token can be discovered.
    def unverified_bot
      allow(Script).to receive(:exists?).with('lnet').and_return(false)
      plan['auth.test'].clear
      plan['auth.test'] << failure(:ok_false)
      bot = described_class.new
      expect(bot.error_message).to include('lnet.lic not found')
      plan['auth.test'].clear
      sleeps.clear
      bot
    end

    it 'bounds the token check of the reconnect a message triggers' do
      bot = unverified_bot
      plan['auth.test'] << failure(:econnreset)

      result, elapsed, delta = measure { bot.direct_message('alice', 'help') }

      expect(result).to be_nil
      expect(elapsed).to be < send_budget
      expect(delta['auth.test']).to eq(1)
      expect(calls['users.list']).to eq(0)
    end

    it 'abandons a hung token check at the deadline' do
      bot = unverified_bot
      stub_const("#{described_class}::SEND_REQUEST_BUDGET", 0.2)
      plan['auth.test'] << -> { Kernel.sleep(5) }

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = bot.direct_message('alice', 'help')
      wall = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      expect(result).to be_nil
      expect(wall).to be < 2
    end

    it 'bounds the check of a token found over LNet' do
      bot = unverified_bot
      lnet = double('lnet script', name: 'lnet', unique_buffer: [])
      stub_const('LNet', Module.new)
      allow(LNet).to receive(:server).and_return(double('server', closed?: false))
      allow(Script).to receive(:running).and_return([lnet])
      allow(Script).to receive(:hidden).and_return([])
      caller_script = double('calling script', name: 'caller', want_downstream: true, want_downstream_xml: false)
      allow(caller_script).to receive(:gets)
        .and_return('[Private]-X:Quilsilgas: "slack_token: found-token"')
      allow(Script).to receive(:current).and_return(caller_script)
      plan['auth.test'] << failure(:ok_false)   # the stored token
      plan['auth.test'] << failure(:econnreset) # the token found over LNet

      result, elapsed, delta = measure { bot.direct_message('alice', 'help') }

      expect(result).to be_nil
      expect(elapsed).to be < send_budget
      expect(delta['auth.test']).to eq(2)
      expect(bot.error_message).to include('Unable to locate a Slack token')
    end

    it 'delivers on the next message after an unexpected error in the token check' do
      bot = unverified_bot
      plan['auth.test'] << failure(:econnrefused)
      plan['auth.test'] << ok({})
      plan['users.list'] << users_ok

      expect(bot.direct_message('alice', 'help')).to be_nil
      expect(bot.error_message).to include('Connection refused')

      expect(bot.direct_message('alice', 'help')).to include('ok' => true)
      expect(calls['users.list']).to eq(1)
      expect(posted.map { |p| p['channel'] }).to eq(['U1'])
    end

    it 'keeps the full retry policy for the token check at startup' do
      plan['auth.test'].clear
      plan['auth.test'] << failure(:econnreset)
      plan['auth.test'] << ok({})
      plan['users.list'] << users_ok

      bot = described_class.new

      expect(bot.initialized?).to be true
      expect(calls['auth.test']).to eq(2)
      expect(sleeps.first).to be >= 30
    end

    it 'bounds the users.list step of the reconnect a message triggers' do
      allow(Script).to receive(:exists?).with('lnet').and_return(false)
      UserVars.slack_token = nil
      bot = described_class.new
      expect(bot.error_message).to include('lnet.lic not found')

      UserVars.slack_token = 'valid-token'
      plan['users.list'] << failure(:throttle_long)
      sleeps.clear

      result, elapsed, delta = measure { bot.direct_message('alice', 'help') }

      expect(result).to be_nil
      expect(elapsed).to be < send_budget
      expect(delta).to include('auth.test' => 1, 'users.list' => 1)
    end
  end

  describe 'a manual reconnect! that fails to fetch users.list' do
    it 'keeps the list loaded earlier and keeps delivering' do
      plan['users.list'] << users_ok
      bot = described_class.new
      expect(bot.initialized?).to be true

      Lich::Common::DB_Store.reset!
      plan['users.list'].clear
      plan['users.list'] << failure(:http500)

      expect(bot.reconnect!).to be true
      expect(calls['users.list']).to eq(2)
      expect(bot.initialized?).to be true
      expect(bot.direct_message('alice', 'help')).to include('ok' => true)
      expect(posted.map { |p| p['channel'] }).to eq(['U1'])
    end
  end

  # Scripts share one bot from their own threads. The second message starts
  # while the first one's restore is stuck inside its Slack call.
  describe 'two messages sent at once while the connection is restored' do
    let(:entered) { Queue.new }
    let(:gate) { Queue.new }

    # A transport response that first reports it was reached, then blocks
    # until the spec opens the gate.
    def blocking(response)
      lambda do
        entered << true
        gate.pop
        response.call
      end
    end

    def wait_until_blocked(thread)
      200.times do
        break if thread.status == 'sleep'

        Kernel.sleep(0.01)
      end
      expect(thread.status).to eq('sleep')
    end

    # @return [Array] both direct_message results
    def two_messages(bot)
      first = Thread.new { bot.direct_message('alice', 'one') }
      expect(entered.pop(timeout: 5)).to be(true), 'the first message never reached its Slack call'
      second = Thread.new { bot.direct_message('alice', 'two') }
      wait_until_blocked(second)
      2.times { gate << true }
      [first, second].map { |t| t.join(10) && t.value }
    end

    it 'makes one users.list call during an outage' do
      plan['users.list'] << failure(:http500)
      bot = described_class.new
      wait_out_cooldown
      plan['users.list'].clear
      plan['users.list'] << blocking(failure(:http500))

      results, _elapsed, delta = measure { two_messages(bot) }

      expect(results).to eq([nil, nil])
      expect(delta['users.list']).to eq(1)
      expect(posted).to be_empty
      expect(messages.grep(/not connected/).size).to eq(2)
    end

    it 'delivers both messages from one successful users.list call' do
      plan['users.list'] << failure(:http500)
      bot = described_class.new
      wait_out_cooldown
      plan['users.list'].clear
      plan['users.list'] << blocking(users_ok)

      results, _elapsed, delta = measure { two_messages(bot) }

      expect(results).to all(include('ok' => true))
      expect(delta['users.list']).to eq(1)
      expect(posted.map { |p| p['channel'] }).to eq(%w[U1 U1])
    end

    it 'makes one token check when the token was never verified' do
      allow(Script).to receive(:exists?).with('lnet').and_return(false)
      plan['auth.test'].clear
      plan['auth.test'] << failure(:ok_false)
      bot = described_class.new
      plan['auth.test'].clear
      plan['auth.test'] << blocking(failure(:ok_false))

      results, _elapsed, delta = measure { two_messages(bot) }

      expect(results).to eq([nil, nil])
      expect(delta['auth.test']).to eq(1)
      expect(bot.error_message).to include('lnet.lic not found')
    end

    it 'lets a later message make its own attempt once the shared one ended' do
      plan['users.list'] << failure(:http500)
      bot = described_class.new
      wait_out_cooldown
      plan['users.list'].clear
      plan['users.list'] << blocking(failure(:http500))
      two_messages(bot)
      wait_out_cooldown
      plan['users.list'].clear
      plan['users.list'] << users_ok

      expect(bot.direct_message('alice', 'three')).to include('ok' => true)
      expect(calls['users.list']).to eq(3)
    end
  end

  describe 'an initialized bot that does not know the user' do
    before do
      plan['users.list'] << users_ok
    end

    it 'delivers when the shared cache now lists the user, without an HTTP list call' do
      bot = described_class.new
      fresh_cache(members + [{ 'name' => 'bob', 'id' => 'U2' }])

      result, _elapsed, delta = measure { bot.direct_message('bob', 'help') }

      expect(result).to include('ok' => true)
      expect(delta['users.list']).to eq(0)
      expect(posted.map { |p| p['channel'] }).to eq(['U2'])
    end

    it 'still reports the user missing when the cache does not list them either' do
      bot = described_class.new

      result, _elapsed, delta = measure { bot.direct_message('bob', 'help') }

      expect(result).to be_nil
      expect(delta['users.list']).to eq(0)
      expect(messages.last).to match(/user 'bob' not found/)
    end

    it 'keeps a user it knows when the shared cache lists other users only' do
      bot = described_class.new
      fresh_cache([{ 'name' => 'zed', 'id' => 'Z9' }])

      expect(bot.direct_message('alcie', 'typo')).to be_nil
      expect(messages.last).to match(/user 'alcie' not found/)

      expect(bot.direct_message('alice', 'help')).to include('ok' => true)
      expect(posted.map { |p| p['channel'] }).to eq(['U1'])
    end

    it 'adds the user from a cache that lists other users only, keeping the users it knew' do
      bot = described_class.new
      fresh_cache([{ 'name' => 'bob', 'id' => 'U2' }])

      expect(bot.direct_message('bob', 'help')).to include('ok' => true)
      expect(bot.direct_message('alice', 'help')).to include('ok' => true)
      expect(bot.direct_message('bob', 'again')).to include('ok' => true)
      expect(posted.map { |p| p['channel'] }).to eq(%w[U2 U1 U2])
    end

    it 'keeps its list when the shared cache holds an empty list' do
      bot = described_class.new
      Lich::Common::DB_Store.store_data('DR', '_slackbot_users_cache',
                                        { 'members' => [], 'fetched_at' => Time.now.to_i })

      bot.direct_message('bob', 'help')

      expect(bot.direct_message('alice', 'help')).to include('ok' => true)
    end

    context 'when reading the shared cache raises' do
      let(:db_error) { Class.new(StandardError) }

      def make_cache_unreadable
        allow(Lich::Common::DB_Store).to receive(:get_data).and_raise(db_error, 'database is locked')
      end

      it 'reports the user missing instead of raising out of the message call' do
        bot = described_class.new
        make_cache_unreadable

        result = :unset
        expect { result = bot.direct_message('bob', 'help') }.not_to raise_error
        expect(result).to be_nil
        expect(messages.last).to match(/user 'bob' not found/)
        expect(Lich).to have_received(:log).with(/Failed to reload cached users list: .*database is locked/)
      end

      it 'keeps its list and keeps delivering to known users' do
        bot = described_class.new
        make_cache_unreadable

        bot.direct_message('bob', 'help')

        expect(bot.initialized?).to be true
        expect(bot.direct_message('alice', 'help')).to include('ok' => true)
        expect(posted.map { |p| p['channel'] }).to eq(['U1'])
      end
    end
  end

  describe 'empty or malformed member lists' do
    it 'treats an ok users.list response with no members as a failure' do
      plan['users.list'] << ok('members' => [])
      bot = described_class.new

      expect(bot.initialized?).to be false
      expect(cache).to be_empty
    end

    it 'ignores a fresh cache entry whose members are missing and fetches from the API' do
      Lich::Common::DB_Store.store_data('DR', '_slackbot_users_cache', { 'fetched_at' => Time.now.to_i })
      plan['users.list'] << users_ok

      bot = described_class.new

      expect(bot.initialized?).to be true
      expect(calls['users.list']).to eq(1)
    end

    it 'ignores a fresh cache entry with an empty member list and fetches from the API' do
      fresh_cache([])
      plan['users.list'] << users_ok

      bot = described_class.new

      expect(bot.initialized?).to be true
      expect(calls['users.list']).to eq(1)
    end
  end

  describe 'a startup throttled until the cache is filled by another process' do
    it 'uses that cache without rewriting its timestamp' do
      written_at = Time.now.to_i - 600
      fill_after = 3
      fill_after.times { plan['users.list'] << failure(:throttle) }
      plan['users.list'].last.then do |throttled|
        plan['users.list'][-1] = lambda do
          Lich::Common::DB_Store.store_data('DR', '_slackbot_users_cache',
                                            { 'members' => members, 'fetched_at' => written_at })
          throttled.call
        end
      end
      plan['users.list'] << -> { raise 'users.list called after the cache was filled' }

      bot = described_class.new

      expect(bot.initialized?).to be true
      expect(calls['users.list']).to eq(fill_after)
      expect(cache['fetched_at']).to eq(written_at)
    end
  end
end
