# frozen_string_literal: true

require_relative '../../spec_helper'
require 'base64'
require 'socket'
require 'timeout'
require 'tmpdir'
require 'uri'
require 'webui/server'

RSpec.describe Lich::WebUI::Server do
  def request(server, target, headers = {})
    request_headers = { 'Host' => "127.0.0.1:#{server.port}", 'Connection' => 'close' }.merge(headers)
    lines = ["GET #{target} HTTP/1.1"]
    request_headers.each { |name, value| lines << "#{name}: #{value}" }
    raw_request(server, lines.join("\r\n") + "\r\n\r\n")
  end

  def raw_request(server, bytes)
    socket = TCPSocket.new(server.host, server.port)
    socket.write(bytes)
    Timeout.timeout(3) { socket.read }
  ensure
    socket&.close
  end

  def authenticate(server)
    uri = URI(server.launch_url)
    response = request(server, uri.request_uri, 'Sec-Fetch-Site' => 'none', 'Sec-Fetch-Mode' => 'navigate')
    response[/^Set-Cookie: ([^;]+)/i, 1]
  end

  def build_server(logs: [], handler: proc { |_connection, _message| }, file_service: nil, pages: -> { [] })
    described_class.new(
      assets_dir: @assets_dir, pages_provider: pages, message_handler: handler, file_service: file_service,
      logger: ->(level, message) { logs << [level, message] }
    )
  end

  # Opens /ws with the given header overrides; returns [socket, response head].
  def upgrade(server, cookie: nil, origin: :same, host: nil)
    socket = TCPSocket.new(server.host, server.port)
    lines = [
      'GET /ws HTTP/1.1', "Host: #{host || "127.0.0.1:#{server.port}"}", 'Upgrade: websocket',
      'Connection: Upgrade', 'Sec-WebSocket-Version: 13',
      "Sec-WebSocket-Key: #{Base64.strict_encode64('0123456789abcdef')}"
    ]
    lines << "Origin: #{origin == :same ? "http://127.0.0.1:#{server.port}" : origin}" if origin
    lines << "Cookie: #{cookie}" if cookie
    socket.write(lines.join("\r\n") + "\r\n\r\n")
    head = +''
    Timeout.timeout(3) do
      until head.end_with?("\r\n\r\n")
        byte = socket.read(1)
        break unless byte

        head << byte
      end
    end
    [socket, head]
  end

  def read_server_message(socket, seconds = 3)
    Timeout.timeout(seconds) do
      data = +''
      loop do
        frame = Lich::WebUI::WebSocket.read_frame(socket, require_mask: false, allow_fragments: true)
        return frame unless frame
        return frame if frame.opcode >= Lich::WebUI::WebSocket::OPCODE_CLOSE

        data << frame.payload
        break Lich::WebUI::WebSocket::Frame.new(Lich::WebUI::WebSocket::OPCODE_TEXT, data, true) if frame.final
      end
    end
  end

  def wait_for_release(server)
    Timeout.timeout(3) do
      sleep 0.005 until server.instance_variable_get(:@client_sockets).empty? &&
                        server.instance_variable_get(:@connections).empty?
    end
  end

  around do |example|
    Dir.mktmpdir('webui-assets') do |assets_dir|
      File.write(File.join(assets_dir, 'index.html'), '<!doctype html><title>Lich</title>')
      @assets_dir = assets_dir
      example.run
    end
  end

  it 'refuses /ws without the cookie, with a foreign or missing Origin, or a foreign Host, and delivers nothing' do
    delivered = Queue.new
    server = build_server(handler: ->(connection, message) { delivered << [connection, message] }).start
    cookie = authenticate(server)
    attempts = [
      { cookie: nil },
      { cookie: "lich_webui_#{server.port}=#{'0' * 64}" },
      { cookie: cookie, origin: 'http://evil.test' },
      { cookie: cookie, origin: "http://127.0.0.1:#{server.port + 1}" },
      { cookie: cookie, origin: nil },
      { cookie: cookie, host: 'evil.test' },
    ]
    # After the server closes a refused socket, a client read ends in EOF or a reset.
    # Windows reports a closed-then-reset connection as ECONNABORTED; elsewhere that
    # error stays a failure.
    closed_by_server = [Errno::EPIPE, Errno::ECONNRESET]
    closed_by_server << Errno::ECONNABORTED if Gem.win_platform?
    attempts.each do |options|
      socket, head = upgrade(server, **options)
      expect(head).to start_with('HTTP/1.1 403 Forbidden'), options.inspect
      rest = begin
        socket.write(Lich::WebUI::WebSocket.encode_client_frame(JSON.generate(type: 'attach', page: 'p', version: '1')))
        Timeout.timeout(3) { socket.read }
      rescue *closed_by_server
        ''
      end
      expect(rest).not_to include('hello')
      socket.close
    end

    wait_for_release(server)
    expect(delivered).to be_empty
  ensure
    server&.stop
  end

  it 'serves /files only to authenticated same-origin requests and refuses traversal' do
    Dir.mktmpdir('webui-files') do |root|
      Dir.mkdir(File.join(root, 'images'))
      File.binwrite(File.join(root, 'images', 'icon.png'), 'png-bytes')
      File.binwrite(File.join(root, 'secret.png'), 'outside')
      files = Lich::WebUI::FileService.new(application_roots: [root])
      files.register('icons', File.join(root, 'images'), owner: Object.new)
      server = build_server(file_service: files).start
      cookie = authenticate(server)

      ok = request(server, '/files/icons/icon.png', 'Cookie' => cookie)
      expect(ok).to start_with('HTTP/1.1 200 OK')
      expect(ok).to include('Content-Type: image/png', 'Content-Length: 9')
      expect(ok).to end_with("\r\n\r\npng-bytes")
      expect(request(server, '/files/icons/icon.png')).to start_with('HTTP/1.1 403 Forbidden')
      expect(request(server, '/files/icons/icon.png', 'Cookie' => cookie, 'Origin' => 'http://evil.test'))
        .to start_with('HTTP/1.1 403 Forbidden')
      expect(request(server, '/files/icons/icon.png', 'Cookie' => cookie, 'Host' => 'evil.test'))
        .to start_with('HTTP/1.1 403 Forbidden')
      %w[/files/icons/../secret.png /files/icons/%2e%2e/secret.png /files/icons/%2E%2E%2Fsecret.png
         /files/other/icon.png /files/icons/missing.png].each do |path|
        expect(request(server, path, 'Cookie' => cookie)).to start_with('HTTP/1.1 404 Not Found'), path
      end
      wait_for_release(server)
    ensure
      server&.stop
    end
  end

  it 'refuses oversized headers and any request body, releasing each slot' do
    server = build_server.start
    cookie = authenticate(server)
    huge = "GET / HTTP/1.1\r\nHost: 127.0.0.1:#{server.port}\r\nX-Pad: #{'a' * described_class::MAX_HEADER_BYTES}\r\n\r\n"
    expect(raw_request(server, huge)).to start_with('HTTP/1.1 400 Bad Request')
    expect(request(server, '/', 'Cookie' => cookie, 'Content-Length' => '5')).to start_with('HTTP/1.1 400 Bad Request')
    expect(request(server, '/', 'Cookie' => cookie, 'Content-Length' => 'nope')).to start_with('HTTP/1.1 400 Bad Request')
    expect(request(server, '/', 'Cookie' => cookie, 'Content-Length' => (2**40).to_s)).to start_with('HTTP/1.1 400 Bad Request')
    wait_for_release(server)
  ensure
    server&.stop
  end

  it 'streams a large image without reading the whole file into memory' do
    Dir.mktmpdir('webui-files') do |root|
      bytes = Random.new(7).bytes(3 * 1024 * 1024)
      File.binwrite(File.join(root, 'big.png'), bytes)
      files = Lich::WebUI::FileService.new(application_roots: [root])
      files.register('big', root, owner: Object.new)
      server = build_server(file_service: files).start
      cookie = authenticate(server)
      expect(File).not_to receive(:binread)

      response = request(server, '/files/big/big.png', 'Cookie' => cookie)
      head, body = response.split("\r\n\r\n", 2)
      expect(head).to include("Content-Length: #{bytes.bytesize}")
      expect(body.b).to eq(bytes)
    ensure
      server&.stop
    end
  end

  it 'lets a token redemption through while stalled header sockets fill the pending pool' do
    stub_const("#{described_class}::MAX_PENDING_CLIENTS", 2)
    server = build_server.start
    stalled = Array.new(2) { TCPSocket.new(server.host, server.port) }
    Timeout.timeout(3) { sleep 0.005 until server.instance_variable_get(:@pending_sockets).size == 2 }

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect(authenticate(server)).to match(/\Alich_webui_\d+=\h{64}\z/)
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < described_class::READ_TIMEOUT
    expect(Timeout.timeout(3) { stalled.first.read }).to eq('')
    expect(server.instance_variable_get(:@pending_sockets).size).to be <= 2
  ensure
    stalled&.each(&:close)
    server&.stop
  end

  it 'pings an idle WebSocket, keeps it while it answers and retires it after silence' do
    stub_const("#{described_class}::WS_PING_INTERVAL", 0.1)
    stub_const("#{described_class}::WS_IDLE_TIMEOUT", 0.5)
    server = build_server.start
    cookie = authenticate(server)
    answering, = upgrade(server, cookie: cookie)
    silent, = upgrade(server, cookie: cookie)
    [answering, silent].each { |socket| expect(JSON.parse(read_server_message(socket).payload)['type']).to eq('hello') }

    3.times do
      ping = read_server_message(answering)
      expect(ping.opcode).to eq(Lich::WebUI::WebSocket::OPCODE_PING)
      answering.write(Lich::WebUI::WebSocket.encode_client_frame(ping.payload, opcode: Lich::WebUI::WebSocket::OPCODE_PONG))
    end
    expect(read_server_message(silent).opcode).to eq(Lich::WebUI::WebSocket::OPCODE_PING)
    closing = read_server_message(silent)
    expect(closing.nil? || closing.close?).to be(true)
    expect(Timeout.timeout(3) { silent.read }).to eq('')
    expect(server.instance_variable_get(:@connections).size).to eq(1)
  ensure
    [answering, silent].each { |socket| socket&.close }
    server&.stop
  end

  it 'retires a WebSocket that stalls mid-frame and releases its slot' do
    stub_const("#{described_class}::WS_MESSAGE_TIMEOUT", 0.2)
    logs = []
    server = build_server(logs: logs).start
    socket, = upgrade(server, cookie: authenticate(server))
    read_server_message(socket)
    socket.write(Lich::WebUI::WebSocket.encode_client_frame('x' * 300).byteslice(0, 12))

    expect(Timeout.timeout(3) { socket.read }).to be_a(String)
    wait_for_release(server)
    expect(logs).to include([:warning, 'WebUI websocket refusal=Lich::WebUI::WebSocket::ProtocolError'])
  ensure
    socket&.close
    server&.stop
  end

  it 'stops promptly while a WebSocket is stalled mid-frame' do
    server = build_server.start
    socket, = upgrade(server, cookie: authenticate(server))
    read_server_message(socket)
    socket.write(Lich::WebUI::WebSocket.encode_client_frame('x' * 300).byteslice(0, 12))
    sleep 0.05

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    server.stop
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 2
    expect(Timeout.timeout(3) { socket.read }).to be_a(String)
  ensure
    socket&.close
    server&.stop
  end

  it 'delivers hello before a broadcast that races connection bootstrap' do
    entered = Queue.new
    release = Queue.new
    gated = true
    pages = lambda do
      if gated
        gated = false
        entered << true
        release.pop
      end
      []
    end
    server = build_server(pages: pages).start
    cookie = authenticate(server)
    client = Thread.new { upgrade(server, cookie: cookie) }
    entered.pop
    broadcaster = Thread.new { server.broadcast(type: 'pages', pages: ['late']) }
    sleep 0.1
    release << true
    socket, = client.value
    broadcaster.join(3)

    expect(JSON.parse(read_server_message(socket).payload)['type']).to eq('hello')
    expect(JSON.parse(read_server_message(socket).payload)).to eq('type' => 'pages', 'pages' => ['late'])
  ensure
    release << true
    socket&.close
    server&.stop
  end

  it 'contains a broken pipe while answering a refused request and keeps the original diagnostic' do
    logs = []
    server = build_server(logs: logs)
    client, accepted = Socket.pair(:UNIX, :STREAM, 0)
    client.write("BROKEN\r\n\r\n")
    allow(server).to receive(:respond_error).and_raise(Errno::EPIPE)

    expect { server.send(:handle_client, accepted) }.not_to raise_error
    expect(logs).to eq([[:warning, 'WebUI request refused=Lich::WebUI::Error']])
    expect(accepted).to be_closed
  ensure
    client&.close
    accepted&.close unless accepted&.closed?
  end
end
