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

  it 'refuses any configured non-loopback host before binding' do
    expect do
      described_class.new(
        assets_dir: @assets_dir, pages_provider: -> { [] }, message_handler: proc {}, host: '0.0.0.0'
      )
    end.to raise_error(ArgumentError, /must be loopback/)
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
    expect(JSON.parse(hello.payload)).to include('type' => 'hello', 'contract_version' => '2.5.0')
    expect(viewer_id).to start_with('viewer-')
    expect(message).to eq(type: 'attach', page: 'page-abc', version: '2.5.0')
  ensure
    socket&.close
    server&.stop
  end
end
