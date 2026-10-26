# frozen_string_literal: true

require_relative '../../spec_helper'
require 'socket'
require 'timeout'
require 'uri'
require 'webui/server'

RSpec.describe Lich::WebUI::Server do
  def request(server, target, headers = {})
    socket = TCPSocket.new(server.host, server.port)
    request_headers = { 'Host' => "127.0.0.1:#{server.port}", 'Connection' => 'close' }.merge(headers)
    lines = ["GET #{target} HTTP/1.1"]
    request_headers.each { |name, value| lines << "#{name}: #{value}" }
    socket.write(lines.join("\r\n") + "\r\n\r\n")
    Timeout.timeout(2) { socket.read }
  ensure
    socket&.close
  end

  def authenticate(server)
    uri = URI(server.launch_url)
    response = request(server, uri.request_uri, 'Sec-Fetch-Site' => 'none', 'Sec-Fetch-Mode' => 'navigate')
    cookie = response[/^Set-Cookie: ([^;]+)/i, 1]
    [uri, response, cookie]
  end

  def build_server(assets_dir, logs: [], handler: proc { |_connection, _message| })
    described_class.new(
      assets_dir: assets_dir, pages_provider: -> { [] }, message_handler: handler,
      logger: ->(level, message) { logs << [level, message] }
    )
  end

  around do |example|
    Dir.mktmpdir('webui-assets') do |assets_dir|
      File.write(File.join(assets_dir, 'index.html'), '<!doctype html><title>Lich</title>')
      File.write(File.join(assets_dir, 'app.js'), 'document.body.textContent = "Lich";')
      File.write(File.join(assets_dir, 'app.css'), 'body { display: block; }')
      @assets_dir = assets_dir
      example.run
    end
  end

  it 'keeps serving after the initiating script group is stopped' do
    server = build_server(@assets_dir)
    script_group = ThreadGroup.new
    gate = Queue.new
    starter = Thread.new { gate.pop; server.start }
    script_group.add(starter)
    gate << true
    starter.value
    port = server.port
    script_group.list.each { |worker| worker.kill.join }

    expect(server).to be_running
    expect { server.start }.not_to raise_error
    expect(server.port).to eq(port)
    expect(authenticate(server)[1]).to start_with('HTTP/1.1 302 Found')
  ensure
    server&.stop
  end

  it 'recovers a dead accept thread without a failed first restart' do
    server = build_server(@assets_dir).start
    server.instance_variable_get(:@accept_thread).kill.join

    expect { server.start }.not_to raise_error
    expect(authenticate(server)[1]).to start_with('HTTP/1.1 302 Found')
  ensure
    server&.stop
  end

  it 'does not retain clients that finish before the accept loop records them' do
    listener = double('listener')
    socket = double('client socket')
    server = described_class.new(
      assets_dir: @assets_dir, pages_provider: -> { [] }, message_handler: proc {},
      thread_factory: ->(*args, &block) { Thread.new(*args, &block).tap(&:join) }
    )
    server.instance_variable_set(:@server, listener)
    server.instance_variable_get(:@client_threads) << Thread.new {}.tap(&:join)
    allow(server).to receive(:handle_client).with(socket)
    accepted = false
    allow(listener).to receive(:accept) do
      if accepted
        server.instance_variable_set(:@stopping, true)
        raise IOError
      end

      accepted = true
      socket
    end

    server.send(:accept_loop)

    expect(server.instance_variable_get(:@client_threads)).to be_empty
  end

  it 'refuses any configured non-loopback host before binding' do
    expect do
      described_class.new(
        assets_dir: @assets_dir, pages_provider: -> { [] }, message_handler: proc {}, host: '0.0.0.0'
      )
    end.to raise_error(ArgumentError, /must be loopback/)
  end

  it 'bounds sockets before creating workers and admits a new client after release' do
    stub_const('Lich::WebUI::Server::MAX_CLIENTS', 2)
    admitted = Queue.new
    server = build_server(@assets_dir)
    allow(server).to receive(:handle_client).and_wrap_original do |original, socket|
      admitted << true
      original.call(socket)
    end
    server.start
    sockets = Array.new(2) { TCPSocket.new(server.host, server.port) }
    Timeout.timeout(2) { 2.times { admitted.pop } }
    excess = TCPSocket.new(server.host, server.port)
    expect(Timeout.timeout(2) { excess.read }).to eq('')
    expect(admitted).to be_empty
    sockets.first.close
    Timeout.timeout(2) do
      sleep 0.005 until server.instance_variable_get(:@client_sockets).size == 1
    end
    expect(authenticate(server)[1]).to start_with('HTTP/1.1 302 Found')
  ensure
    excess&.close
    sockets&.each { |socket| socket.close unless socket.closed? }
    server&.stop
  end

  it 'uses an ephemeral loopback port and authenticates through a one-shot clean redirect', security_id: 'sec-auth-fallback' do
    logs = []
    server = build_server(@assets_dir, logs: logs).start
    uri, auth_response, cookie = authenticate(server)

    expect(server.port).to be_positive
    expect(auth_response).to start_with('HTTP/1.1 302 Found')
    expect(auth_response).to include('Location: /', 'HttpOnly', 'SameSite=Strict', 'Cache-Control: no-store', 'Referrer-Policy: no-referrer')
    token = URI.decode_www_form(uri.query).to_h.fetch('token')
    expect(auth_response).not_to include(token)
    expect(logs.to_s).not_to include(uri.query)
    expect(request(server, uri.request_uri)).to start_with('HTTP/1.1 403 Forbidden')

    page = request(server, '/', 'Cookie' => cookie, 'Sec-Fetch-Site' => 'same-origin', 'Sec-Fetch-Mode' => 'navigate')
    expect(page).to start_with('HTTP/1.1 200 OK')
    expect(page).to include('Content-Security-Policy:', "default-src 'none'", 'X-Content-Type-Options: nosniff')
  ensure
    server&.stop
  end

  it 'serves exactly the shipped ordered scripts behind authentication, origin checks and cache validation' do
    assets = File.expand_path('../../../lib/webui/assets', __dir__)
    html = File.read(File.join(assets, 'index.html'))
    names = html.scan(%r{<script src="/assets/([a-z_]+\.js)" defer></script>}).flatten
    expect(names.size).to eq(6)
    expect(described_class::ASSET_ROUTES.keys).to match_array(['/', '/assets/app.css', *names.map { |name| "/assets/#{name}" }])
    server = build_server(assets).start
    _uri, _response, cookie = authenticate(server)
    names.each do |name|
      target = "/assets/#{name}"
      expect(request(server, target)).to start_with('HTTP/1.1 403 Forbidden')
      expect(request(server, target, 'Cookie' => cookie, 'Origin' => 'http://evil.test')).to start_with('HTTP/1.1 403 Forbidden')
      response = request(server, target, 'Cookie' => cookie)
      expect(response).to start_with('HTTP/1.1 200 OK')
      expect(response).to include('Content-Type: text/javascript; charset=utf-8', "script-src 'self'")
      expect(response.split("\r\n\r\n", 2).last).to eq(File.binread(File.join(assets, name)))
      etag = response[/^ETag: (.+)\r$/, 1]
      expect(etag).not_to be_nil
      expect(request(server, target, 'Cookie' => cookie, 'If-None-Match' => etag)).to start_with('HTTP/1.1 304 Not Modified')
    end
    ['/assets/not_allowed.js', '/assets/../app.js', '/assets/renderers_table.js/extra'].each do |target|
      expect(request(server, target, 'Cookie' => cookie)).to start_with('HTTP/1.1 404 Not Found')
    end
  ensure
    server&.stop
  end

  it 'rejects unauthenticated, foreign Host, foreign Origin, and cross-site metadata requests', security_id: 'sec-host-origin' do
    server = build_server(@assets_dir).start
    _uri, _response, cookie = authenticate(server)

    expect(request(server, '/')).to start_with('HTTP/1.1 403 Forbidden')
    expect(request(server, '/', 'Host' => 'evil.test')).to start_with('HTTP/1.1 403 Forbidden')
    expect(request(server, '/', 'Cookie' => cookie, 'Origin' => 'http://evil.test')).to start_with('HTTP/1.1 403 Forbidden')
    expect(request(server, '/', 'Cookie' => cookie, 'Sec-Fetch-Site' => 'cross-site')).to start_with('HTTP/1.1 403 Forbidden')
  ensure
    server&.stop
  end

  it 'rejects a session cookie from a prior server session' do
    first = build_server(@assets_dir).start
    _uri, _response, old_cookie = authenticate(first)
    first.stop
    second = build_server(@assets_dir).start

    expect(request(second, '/', 'Cookie' => old_cookie)).to start_with('HTTP/1.1 403 Forbidden')
  ensure
    first&.stop
    second&.stop
  end

  it 'redeems file-bootstrap navigation without weakening authenticated content checks' do
    server = build_server(@assets_dir).start
    uri = URI(server.launch_url(to: '/?page=example'))
    navigation = { 'Sec-Fetch-Site' => 'cross-site', 'Sec-Fetch-Mode' => 'navigate', 'Sec-Fetch-Dest' => 'document' }
    expect(request(server, uri.request_uri, navigation.merge('Sec-Fetch-Dest' => 'image'))).to start_with('HTTP/1.1 403')
    response = request(server, uri.request_uri, navigation)
    expect(response).to start_with('HTTP/1.1 200 OK')
    expect(response).to include('url=/?page=example', 'SameSite=Strict', 'HttpOnly')
    expect(response).not_to include('token=')
    expect(request(server, uri.request_uri, navigation)).to start_with('HTTP/1.1 403')
    cookie = response[/^Set-Cookie: ([^;]+)/i, 1]
    expect(request(server, '/', navigation.merge('Cookie' => cookie))).to start_with('HTTP/1.1 403')
    expect(request(server, '/', 'Cookie' => cookie, 'Sec-Fetch-Site' => 'same-origin')).to start_with('HTTP/1.1 200')
  ensure
    server&.stop
  end

  it 'refuses redirects that browsers can normalize into another authority' do
    server = build_server(@assets_dir).start
    ["/\\evil.test", "/\tevil.test", '//evil.test', " /safe", "/safe\n"].each do |target|
      uri = URI(server.launch_url)
      token = URI.decode_www_form(uri.query).to_h.fetch('token')
      response = request(server, "/auth?#{URI.encode_www_form(token: token, to: target)}")
      expect(response).to include("Location: /\r\n")
    end
  ensure
    server&.stop
  end

  it 'keeps two localhost sessions authenticated in one browser cookie jar' do
    first = build_server(@assets_dir).start
    second = build_server(@assets_dir).start
    cookies = [authenticate(first).last, authenticate(second).last]
    jar = cookies.to_h { |cookie| cookie.split('=', 2) }
    expect(jar.size).to eq(2)
    header = jar.map { |name, value| "#{name}=#{value}" }.join('; ')

    [first, second].each do |server|
      expect(request(server, '/', 'Cookie' => header)).to start_with('HTTP/1.1 200 OK')
    end
  ensure
    first&.stop
    second&.stop
  end

  it 'bounds a WebSocket write when the peer stops reading' do
    stub_const('Lich::WebUI::Server::Connection::WRITE_TIMEOUT', 0.05)
    sender, receiver = Socket.pair(:UNIX, :STREAM, 0)
    sender.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDBUF, 4096)
    connection = described_class::Connection.new(sender)
    worker = Thread.new { connection.send_text('x' * (1024 * 1024)) }

    expect(Timeout.timeout(1) { worker.value }).to be(false)
    expect(connection).not_to be_alive
  ensure
    sender&.close
    receiver&.close
    worker&.kill&.join
  end

  it 'retires a stream if its writer is killed partway through a frame' do
    sender, receiver = Socket.pair(:UNIX, :STREAM, 0)
    sender.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDBUF, 4096)
    connection = described_class::Connection.new(sender)
    worker = Thread.new { connection.send_text('x' * (1024 * 1024)) }
    expect(Timeout.timeout(2) { receiver.read(2) }.bytesize).to eq(2)
    worker.kill.join(2)

    expect(connection).not_to be_alive
    expect(connection.send_text('must not append to an incomplete frame')).to be(false)
    expect(Timeout.timeout(2) { receiver.read }).to be_a(String)
  ensure
    worker&.kill&.join
    sender&.close
    receiver&.close
  end

  it 'sends a Close frame before shutting down an idle WebSocket' do
    sender, receiver = Socket.pair(:UNIX, :STREAM, 0)
    connection = described_class::Connection.new(sender)
    server = build_server(@assets_dir)
    server.instance_variable_get(:@connections) << connection
    server.stop

    reply = Timeout.timeout(2) { Lich::WebUI::WebSocket.read_frame(receiver, require_mask: false) }
    expect(reply).not_to be_nil
    expect(reply).to be_close
    expect(reply.payload.unpack1('n')).to eq(1000)
    expect(Timeout.timeout(2) { receiver.read }).to eq('')
  ensure
    server&.stop
    sender&.close
    receiver&.close
  end

  it 'includes waiting for another WebSocket writer in the write deadline' do
    stub_const('Lich::WebUI::Server::Connection::WRITE_TIMEOUT', 0.05)
    sender, receiver = Socket.pair(:UNIX, :STREAM, 0)
    connection = described_class::Connection.new(sender)
    lock = connection.instance_variable_get(:@write_mutex)
    lock.lock
    worker = Thread.new { connection.send_text('queued') }

    expect(Timeout.timeout(1) { worker.value }).to be(false)
    expect(connection).not_to be_alive
  ensure
    lock&.unlock if lock&.owned?
    sender&.close
    receiver&.close
    worker&.kill&.join
  end

  it 'authenticates WebSocket upgrade, emits hello, and delivers strict messages' do
    delivered = Queue.new
    server = build_server(@assets_dir, handler: ->(connection, message) { delivered << [connection.viewer_id, message] }).start
    _uri, _response, cookie = authenticate(server)
    socket = TCPSocket.new(server.host, server.port)
    key = Base64.strict_encode64('0123456789abcdef')
    socket.write([
      'GET /ws HTTP/1.1', "Host: 127.0.0.1:#{server.port}", 'Upgrade: websocket',
      'Connection: Upgrade', 'Sec-WebSocket-Version: 13', "Sec-WebSocket-Key: #{key}",
      "Origin: http://127.0.0.1:#{server.port}", "Cookie: #{cookie}", '', '',
    ].join("\r\n"))
    response_head = +''
    Timeout.timeout(2) do
      response_head << socket.read(1) until response_head.end_with?("\r\n\r\n")
    end
    hello = Lich::WebUI::WebSocket.read_frame(socket, require_mask: false)
    socket.write(Lich::WebUI::WebSocket.encode_client_frame(JSON.generate(
                                                              type: 'attach', page: 'page-abc', version: '2.5.0'
                                                            )))
    viewer_id, message = delivered.pop

    expect(response_head).to start_with('HTTP/1.1 101 Switching Protocols')
    expect(JSON.parse(hello.payload)).to include('type' => 'hello', 'contract_version' => '2.51.0')
    expect(viewer_id).to start_with('viewer-')
    expect(message).to eq(type: 'attach', page: 'page-abc', version: '2.5.0')
    socket.write(Lich::WebUI::WebSocket.encode_client_frame([1000].pack('n'), opcode: Lich::WebUI::WebSocket::OPCODE_CLOSE))
    reply = Timeout.timeout(2) { Lich::WebUI::WebSocket.read_frame(socket, require_mask: false) }
    expect(reply).not_to be_nil
    expect(reply).to be_close
  ensure
    socket&.close
    server&.stop
  end
end
