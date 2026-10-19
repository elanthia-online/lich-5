# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'json'
require 'net/http'
require 'openssl'
require 'socket'

require File.join(LIB_DIR, 'dragonrealms', 'commons', 'slackbot.rb')

# Connection-level failures (refused, unreachable, TLS errors) through the
# real SlackBot code and real Net::HTTP/OpenSSL. API_URL points at a
# loopback TLS server whose behaviour each example picks; its self-signed
# certificate is trusted by adding it to each Net::HTTP's cert store, so the
# client still runs with VERIFY_PEER exactly as in production. Only
# SlackBot#sleep (recorded, never waited) and, for the unreachable cases,
# TCPSocket.open stand in for the outside world, plus LNet and lnet.lic
# where an example installs them.
RSpec.describe Lich::DragonRealms::SlackBot, 'connection failures' do
  let(:key) { OpenSSL::PKey::EC.generate('prime256v1') }
  let(:cert) do
    name = OpenSSL::X509::Name.parse('/CN=127.0.0.1')
    OpenSSL::X509::Certificate.new.tap do |c|
      c.version = 2
      c.serial = 1
      c.subject = name
      c.issuer = name
      c.public_key = key
      c.not_before = Time.now - 60
      c.not_after = Time.now + 3600
      ef = OpenSSL::X509::ExtensionFactory.new(c, c)
      c.add_extension(ef.create_extension('subjectAltName', 'IP:127.0.0.1', false))
      c.add_extension(ef.create_extension('basicConstraints', 'CA:TRUE', true))
      c.sign(key, OpenSSL::Digest.new('SHA256'))
    end
  end
  let(:server) { TCPServer.new('127.0.0.1', 0) }
  let(:port) { server.addr[1] }
  # What the server does with each connection: :ok, :plaintext or :drop_mid_response.
  let(:mode) { { value: :ok } }
  let(:trust_server_cert) { { value: true } }
  let(:requests) { Hash.new(0) }
  let(:sleeps) { [] }
  let(:messages) { [] }
  let(:logs) { [] }
  let(:lnet_chats) { [] }
  let(:members) { [{ 'name' => 'alice', 'id' => 'U1' }] }
  let(:clock) { { offset: 0.0 } }

  def ssl_context
    OpenSSL::SSL::SSLContext.new.tap do |ctx|
      ctx.cert = cert
      ctx.key = key
    end
  end

  def read_request(ssl)
    head = +''
    head << ssl.readpartial(65_536) until head.include?("\r\n\r\n")
    headers, body = head.split("\r\n\r\n", 2)
    length = headers[/^content-length:\s*(\d+)/i, 1].to_i
    body << ssl.readpartial(65_536) while body.bytesize < length
    [headers[%r{\APOST /api/(\S+)}, 1], URI.decode_www_form(body).to_h['token']]
  end

  def json_reply(ssl, payload)
    body = payload.to_json
    ssl.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
  end

  def handle(conn)
    if mode[:value] == :plaintext
      # Read the ClientHello first and let the client close first: closing
      # with unread input would send a reset, which the client could see
      # as ECONNRESET instead of the TLS error.
      conn.readpartial(65_536)
      conn.write("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
      conn.read if conn.wait_readable(2)
      return
    end

    ssl = OpenSSL::SSL::SSLSocket.new(conn, ssl_context)
    ssl.accept
    method, token = read_request(ssl)
    requests[method] += 1
    if token == 'throttle-token'
      ssl.write("HTTP/1.1 429 Too Many Requests\r\nRetry-After: 1\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
      return ssl.sysclose
    end
    if token == 'html-token'
      # A 200 page that is not JSON, as a proxy or captive portal might send.
      page = '<html><body>Access denied</body></html>'
      ssl.write("HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: #{page.bytesize}\r\nConnection: close\r\n\r\n#{page}")
      return ssl.sysclose
    end
    if mode[:value] == :drop_mid_response || token == 'drop-token'
      ssl.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 100\r\n\r\n{\"ok\":")
      return # closes the TCP socket below with no TLS close_notify
    end

    reply = if method == 'users.list'
              { 'ok' => true, 'members' => members }
            elsif token == 'stale-token'
              { 'ok' => false, 'error' => 'invalid_auth' }
            else
              { 'ok' => true }
            end
    json_reply(ssl, reply)
    ssl.sysclose
  rescue StandardError
    nil # the client gave up (e.g. it rejected the certificate)
  ensure
    conn.close unless conn.closed?
  end

  def closed_port
    s = TCPServer.new('127.0.0.1', 0)
    s.addr[1].tap { s.close }
  end

  def point_api_at(port_number)
    stub_const("#{described_class}::API_URL", "https://127.0.0.1:#{port_number}/api/")
  end

  # Slack answers normally again after a failure set up by an example.
  def make_slack_reachable
    RSpec::Mocks.space.proxy_for(TCPSocket).reset
    point_api_at(port)
    mode[:value] = :ok
    trust_server_cert[:value] = true
  end

  # lnet.lic installed, running and connected, with Quilsilgas answering a
  # token request with +token+. Chats sent over LNet land in lnet_chats.
  def install_lnet(token: 'valid-token')
    stub_const('LNet', Module.new)
    allow(LNet).to receive(:server).and_return(double('lnet server', closed?: false))
    allow(Script).to receive(:exists?).with('lnet').and_return(true)
    allow(Script).to receive(:running?).with('lnet').and_return(true)
    allow(Script).to receive(:running).and_return([double('lnet script', name: 'lnet', unique_buffer: lnet_chats)])
    allow(Script).to receive(:hidden).and_return([])
    allow_any_instance_of(described_class).to receive(:pause)
    allow_any_instance_of(described_class).to receive(:get)
      .and_return(%([Private]-X:Quilsilgas: "slack_token: #{token}"))
  end

  def initialized_bot
    bot = described_class.new
    expect(bot.initialized?).to be true
    sleeps.clear
    messages.clear
    bot
  end

  before do
    UserVars.slack_token = 'valid-token'
    allow(XMLData).to receive(:game).and_return('DR')
    allow(Lich).to receive(:log) { |text| logs << text }
    allow(Lich::Messaging).to receive(:msg) { |_type, text| messages << text }
    allow_any_instance_of(described_class).to receive(:sleep) { |_bot, seconds| sleeps << seconds }
    # lnet.lic is not installed, so a failed token check ends without LNet discovery.
    allow(Script).to receive(:exists?).with('lnet').and_return(false)
    # Lets an example move past the users.list cooldown without waiting.
    allow(Process).to receive(:clock_gettime).and_wrap_original do |original, id, *rest|
      value = original.call(id, *rest)
      id == Process::CLOCK_MONOTONIC && rest.empty? ? value + clock[:offset] : value
    end

    store = OpenSSL::X509::Store.new.tap { |s| s.add_cert(cert) }
    allow(Net::HTTP).to receive(:new).and_wrap_original do |original, *args|
      original.call(*args).tap { |http| http.cert_store = store if trust_server_cert[:value] }
    end

    @server_thread = Thread.new do
      loop do
        conn = server.accept
        Thread.new(conn) { |c| handle(c) }
      end
    rescue IOError
      nil
    end
    point_api_at(port)
  end

  after do
    UserVars.slack_token = nil
    @server_thread&.kill
    server.close unless server.closed?
  end

  it 'talks to the loopback server normally (harness check)' do
    bot = initialized_bot
    expect(bot.direct_message('alice', 'help')).to include('ok' => true)
    expect(requests).to include('auth.test' => 1, 'users.list' => 1, 'chat.postMessage' => 1)
  end

  # Each failure is produced on the real transport; +expected+ is the
  # exception Net::HTTP raises for it, checked so the example cannot pass by
  # producing some other failure.
  failures = {
    'a refused connection'              => {
      expected: Errno::ECONNREFUSED,
      setup: -> { point_api_at(closed_port) }
    },
    'an unreachable host'               => {
      expected: Errno::EHOSTUNREACH,
      setup: -> { allow(TCPSocket).to receive(:open).and_raise(Errno::EHOSTUNREACH) }
    },
    'an unreachable network'            => {
      expected: Errno::ENETUNREACH,
      setup: -> { allow(TCPSocket).to receive(:open).and_raise(Errno::ENETUNREACH) }
    },
    'a server that does not speak TLS'  => {
      expected: OpenSSL::SSL::SSLError,
      setup: -> { mode[:value] = :plaintext }
    },
    'an untrusted certificate'          => {
      expected: OpenSSL::SSL::SSLError,
      setup: -> { trust_server_cert[:value] = false }
    },
    'a connection dropped mid-response' => {
      expected: OpenSSL::SSL::SSLError,
      setup: -> { mode[:value] = :drop_mid_response }
    }
  }

  failures.each do |label, spec|
    context "with #{label}" do
      it "is the #{spec[:expected]} this context is about (harness check)" do
        bot = initialized_bot
        instance_exec(&spec[:setup])
        uri = URI.parse("#{described_class::API_URL}auth.test")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        expect { http.request(Net::HTTP::Post.new(uri.path)) }.to raise_error(spec[:expected])
        expect(bot).to be_initialized
      end

      it 'raises SlackBot::NetworkError from post at once, keeping the cause' do
        bot = initialized_bot
        instance_exec(&spec[:setup])

        expect { bot.send(:post, 'auth.test', { 'token' => 'valid-token' }) }
          .to raise_error(described_class::NetworkError) { |e| expect(e.cause).to be_a(spec[:expected]) }
        expect(sleeps).to be_empty
      end

      it 'returns nil from direct_message without raising, and reports the failure' do
        bot = initialized_bot
        instance_exec(&spec[:setup])

        result = :not_called
        expect { result = bot.direct_message('alice', 'Detected low vitality') }.not_to raise_error
        expect(result).to be_nil
        expect(messages).to include(/Failed to send Slack message to alice: Network error: .*#{spec[:expected]}/)
        expect(messages.grep(/SlackBot: .*SlackBot: /)).to be_empty
        expect(sleeps).to be_empty
      end

      it 'answers false from authed? without raising' do
        bot = initialized_bot
        instance_exec(&spec[:setup])

        expect(bot.authed?('some-token')).to be false
        expect(bot.authed?('some-token', budget: 5)).to be false
        expect(logs.grep(/Could not check a Slack token: .*#{spec[:expected]}/).length).to eq(2)
      end

      it 'builds a bot that is not initialized when it happens at startup' do
        instance_exec(&spec[:setup])

        bot = nil
        expect { bot = described_class.new }.not_to raise_error
        expect(bot.initialized?).to be false
        expect(bot.error_message).to start_with('Slack unavailable: ').and include(spec[:expected].to_s)
        expect(sleeps).to be_empty
      end

      it 'delivers on a later message once Slack is reachable again' do
        instance_exec(&spec[:setup])
        bot = described_class.new
        expect(bot.initialized?).to be false

        make_slack_reachable

        expect(bot.direct_message('alice', 'help')).to include('ok' => true)
        expect(bot.initialized?).to be true
      end

      context 'with lnet.lic installed and connected' do
        before { install_lnet }

        it 'reports Slack unavailable at startup with the cause, and asks LNet for no token' do
          instance_exec(&spec[:setup])

          bot = described_class.new

          expect(bot.initialized?).to be false
          expect(bot.error_message).to start_with('Slack unavailable: ').and include(spec[:expected].to_s)
          expect(bot.error_message).not_to include('SlackBot:')
          expect(messages).to include("SlackBot: #{bot.error_message}")
          expect(logs).to include(a_string_including(spec[:expected].to_s))
          expect(lnet_chats).to be_empty
          expect(sleeps).to be_empty
        end

        it 'asks LNet for no token while messages fail, and delivers once Slack is back' do
          instance_exec(&spec[:setup])
          bot = described_class.new

          3.times { expect(bot.direct_message('alice', 'Detected low vitality')).to be_nil }
          expect(lnet_chats).to be_empty
          expect(bot.error_message).to start_with('Slack unavailable: ')

          make_slack_reachable
          expect(bot.direct_message('alice', 'help')).to include('ok' => true)
          expect(lnet_chats).to be_empty
          expect(UserVars.slack_token).to eq('valid-token')
        end
      end
    end
  end

  context 'with lnet.lic installed and connected' do
    it 'still asks LNet for a token when Slack rejects the stored one' do
      install_lnet(token: 'valid-token')
      UserVars.slack_token = 'stale-token'

      bot = described_class.new

      expect(bot.initialized?).to be true
      expect(lnet_chats).to eq(['chat to Quilsilgas RequestSlackToken'])
      expect(UserVars.slack_token).to eq('valid-token')
      expect(logs).to include(a_string_including('invalid_auth'))
    end

    it 'reports Slack unavailable, and keeps the stored token, when the token found over LNet cannot be checked' do
      install_lnet(token: 'drop-token')
      UserVars.slack_token = 'stale-token'

      bot = described_class.new

      expect(bot.initialized?).to be false
      expect(lnet_chats).to eq(['chat to Quilsilgas RequestSlackToken'])
      expect(bot.error_message).to start_with('Slack unavailable: ').and include('OpenSSL::SSL::SSLError')
      expect(UserVars.slack_token).to eq('stale-token')
    end

    it 'treats a rate-limited token check as Slack unavailable, not as a rejected token' do
      install_lnet(token: 'valid-token')
      UserVars.slack_token = 'throttle-token'

      bot = described_class.new

      expect(bot.initialized?).to be false
      expect(lnet_chats).to be_empty
      expect(bot.error_message).to eq('Slack unavailable: Throttled by Slack API')
      expect(UserVars.slack_token).to eq('throttle-token')
      expect(bot.authed?('throttle-token')).to be false
      expect(logs).to include('SlackBot: Could not check a Slack token: Throttled by Slack API')
    end
    it 'treats a token check answered with a page that is not JSON as Slack unavailable, not as a rejected token' do
      install_lnet(token: 'valid-token')
      UserVars.slack_token = 'html-token'

      bot = described_class.new

      expect(bot.initialized?).to be false
      expect(lnet_chats).to be_empty
      expect(bot.error_message).to start_with('Slack unavailable: Failed to parse Slack API response')
      expect(UserVars.slack_token).to eq('html-token')

      3.times { expect(bot.direct_message('alice', 'help')).to be_nil }
      expect(lnet_chats).to be_empty

      expect(bot.authed?('html-token')).to be false
      expect(logs).to include(a_string_starting_with('SlackBot: Could not check a Slack token: Failed to parse Slack API response'))
      expect(logs).not_to include(a_string_including('Slack token not accepted'))
    end
  end

  context 'when users.list fails this way while a message restores the connection' do
    it 'does not raise, starts the cooldown and keeps the bot uninitialized' do
      members.clear # startup gets an empty list, so the bot is not initialized
      bot = described_class.new
      expect(bot.initialized?).to be false
      members << { 'name' => 'alice', 'id' => 'U1' }
      clock[:offset] += described_class::USERS_LIST_RETRY_COOLDOWN + 1
      mode[:value] = :drop_mid_response

      result = :not_called
      expect { result = bot.direct_message('alice', 'help') }.not_to raise_error
      expect(result).to be_nil
      expect(bot.initialized?).to be false
      expect(bot.error_message).to eq('Slack user list unavailable')
      expect(messages).to include(/Failed to fetch Slack user list: .*SSL/)

      mode[:value] = :ok
      users_list_calls = requests['users.list']
      expect(bot.direct_message('alice', 'help')).to be_nil # inside the cooldown: no new users.list call
      expect(requests['users.list']).to eq(users_list_calls)
    end
  end

  it 'still retries a connection reset with backoff' do
    bot = initialized_bot
    attempts = 0
    allow(TCPSocket).to receive(:open) do
      attempts += 1
      raise Errno::ECONNRESET
    end

    expect { bot.send(:post, 'auth.test', { 'token' => 'valid-token' }) }
      .to raise_error(described_class::NetworkError, /after 5 retries/)
    expect(attempts).to eq(described_class::MAX_NETWORK_RETRIES + 1)
    expect(sleeps.length).to eq(described_class::MAX_NETWORK_RETRIES)
  end

  it 'lets an error that is not a transport failure through post' do
    bot = initialized_bot
    allow(TCPSocket).to receive(:open).and_raise(ArgumentError, 'not a network failure')

    expect { bot.send(:post, 'auth.test', { 'token' => 'valid-token' }) }
      .to raise_error(ArgumentError, /not a network failure/)
  end
end
