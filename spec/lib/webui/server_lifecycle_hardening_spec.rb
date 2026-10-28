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
    socket = TCPSocket.new(server.host, server.port)
    socket.write(lines.join("\r\n") + "\r\n\r\n")
    Timeout.timeout(3) { socket.read }
  ensure
    socket&.close
  end

  def redeem(server, url)
    request(server, URI(url).request_uri, 'Sec-Fetch-Site' => 'none', 'Sec-Fetch-Mode' => 'navigate')
  end

  def build_server(logs: [], handler: proc { |_connection, _message| })
    described_class.new(
      assets_dir: @assets_dir, pages_provider: -> { [] }, message_handler: handler,
      logger: ->(level, message) { logs << [level, message] }
    )
  end

  # Opens an authenticated WebSocket and consumes the 101 head.
  def open_websocket(server, cookie)
    socket = TCPSocket.new(server.host, server.port)
    socket.write([
      'GET /ws HTTP/1.1', "Host: 127.0.0.1:#{server.port}", 'Upgrade: websocket',
      'Connection: Upgrade', 'Sec-WebSocket-Version: 13',
      "Sec-WebSocket-Key: #{Base64.strict_encode64('0123456789abcdef')}",
      "Origin: http://127.0.0.1:#{server.port}", "Cookie: #{cookie}"
    ].join("\r\n") + "\r\n\r\n")
    head = +''
    Timeout.timeout(3) { head << socket.read(1) until head.end_with?("\r\n\r\n") }
    expect(head).to start_with('HTTP/1.1 101')
    socket
  end

  around do |example|
    Dir.mktmpdir('webui-assets') do |assets_dir|
      File.write(File.join(assets_dir, 'index.html'), '<!doctype html><title>Lich</title>')
      @assets_dir = assets_dir
      example.run
    end
  end

  it 'completes stop called from a message handler on its own client worker' do
    outcome = Queue.new
    server = nil
    server = build_server(handler: lambda do |_connection, _message|
      outcome << begin
        server.stop
      rescue StandardError => error
        error
      end
    end).start
    cookie = redeem(server, server.launch_url)[/^Set-Cookie: ([^;]+)/i, 1]
    socket = open_websocket(server, cookie)
    socket.write(Lich::WebUI::WebSocket.encode_client_frame(JSON.generate(type: 'detach', page: 'p', generation: 1)))

    expect(Timeout.timeout(3) { outcome.pop }).to be_nil
    expect(server.running?).to be(false)
    expect(server.instance_variable_get(:@client_threads)).to be_empty
  ensure
    socket&.close
    server&.stop
  end

  it 'refuses Transfer-Encoding framing as a malformed request' do
    server = build_server.start

    response = request(server, '/', 'Transfer-Encoding' => 'chunked')
    expect(response).to start_with('HTTP/1.1 400 Bad Request')
  ensure
    server&.stop
  end

  it 'logs one malformed-request refusal per interval and reports the suppressed count next' do
    logs = []
    server = build_server(logs: logs)
    error = Lich::WebUI::Error.new('malformed request line')

    5.times { server.send(:log_request_refusal, error) }
    expect(logs).to eq([[:warning, 'WebUI request refused=Lich::WebUI::Error']])

    last = server.instance_variable_get(:@refusal_logged_at)
    server.instance_variable_set(:@refusal_logged_at, last - described_class::REFUSAL_LOG_INTERVAL - 1)
    server.send(:log_request_refusal, error)
    expect(logs.last).to eq([:warning, 'WebUI request refused=Lich::WebUI::Error suppressed=4'])
    expect(logs.size).to eq(2)
  end

  it 'logs a handler failure with its raise location but never its message' do
    logs = []
    server = build_server(logs: logs, handler: ->(_connection, _message) { raise ArgumentError, 'secret-payload' })
    connection = instance_double(Lich::WebUI::Server::Connection, send_text: nil)

    server.send(:dispatch_message, connection, JSON.generate(type: 'detach', page: 'p', generation: 1))
    expect(logs.size).to eq(1)
    level, message = logs.first
    expect(level).to eq(:warning)
    expect(message).to match(/\AWebUI handler refusal=ArgumentError at=server_lifecycle_hardening_spec\.rb:\d+:/)
    expect(message).not_to include('secret-payload')
    expect(message).not_to include(File.dirname(__FILE__))
  end

  it 'caps outstanding launch tokens by retiring the oldest' do
    server = build_server.start
    urls = Array.new(described_class::MAX_LAUNCH_TOKENS + 1) { server.launch_url }

    expect(server.instance_variable_get(:@launch_tokens).size).to eq(described_class::MAX_LAUNCH_TOKENS)
    expect(redeem(server, urls.first)).to start_with('HTTP/1.1 403 Forbidden')
    expect(redeem(server, urls.last)).to start_with('HTTP/1.1 302 Found')
  ensure
    server&.stop
  end
end
