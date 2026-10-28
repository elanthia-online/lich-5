# frozen_string_literal: true

require_relative '../../spec_helper'
require 'socket'
require 'timeout'
require 'tmpdir'
require 'uri'
require 'webui/server'

# HTTP responses are written under a deadline, as WebSocket messages are, so a
# peer that stops reading releases its worker and client slot.
RSpec.describe Lich::WebUI::Server do
  # Large enough to fill loopback socket buffers on every supported host.
  let(:body_bytes) { 48 * 1024 * 1024 }

  around do |example|
    Dir.mktmpdir('webui-deadline') do |root|
      @root = root
      File.write(File.join(root, 'index.html'), '<!doctype html><title>Lich</title>')
      example.run
    end
  end

  def build_server(file_service: nil)
    described_class.new(assets_dir: @root, pages_provider: -> { [] }, message_handler: proc {},
                        file_service: file_service)
  end

  def request_lines(server, target, extra = [])
    (["GET #{target} HTTP/1.1", "Host: 127.0.0.1:#{server.port}", 'Connection: close'] + extra)
      .join("\r\n") + "\r\n\r\n"
  end

  def authenticate(server)
    socket = TCPSocket.new(server.host, server.port)
    socket.write(request_lines(server, URI(server.launch_url).request_uri,
                               ['Sec-Fetch-Site: none', 'Sec-Fetch-Mode: navigate']))
    Timeout.timeout(3) { socket.read }[/^Set-Cookie: ([^;]+)/i, 1]
  ensure
    socket&.close
  end

  # Sends a request and reads only the status line of its large response,
  # then stops reading while the server is still writing.
  def stall(server, target, cookie:)
    socket = TCPSocket.new(server.host, server.port)
    socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVBUF, 4096)
    socket.write(request_lines(server, target, ["Cookie: #{cookie}"]))
    expect(Timeout.timeout(3) { socket.read(15) }).to eq('HTTP/1.1 200 OK')
    expect(server.instance_variable_get(:@client_sockets).size).to eq(1)
    socket
  end

  def wait_for_release(server, seconds)
    Timeout.timeout(seconds) do
      sleep 0.01 until server.instance_variable_get(:@client_sockets).empty? &&
                       server.instance_variable_get(:@client_threads).none?(&:alive?)
    end
  end

  it 'releases the worker and slot of a peer that stops reading a streamed image' do
    stub_const("#{described_class}::RESPONSE_WRITE_TIMEOUT", 0.3)
    images = File.join(@root, 'images')
    Dir.mkdir(images)
    File.open(File.join(images, 'big.png'), 'wb') { |file| file.truncate(body_bytes) }
    files = Lich::WebUI::FileService.new(application_roots: [@root])
    files.register('big', images, owner: Object.new)
    server = build_server(file_service: files).start
    stalled = stall(server, '/files/big/big.png', cookie: authenticate(server))

    wait_for_release(server, 3)
    expect(server.instance_variable_get(:@client_sockets)).to be_empty
  ensure
    stalled&.close
    server&.stop
  end

  it 'releases the worker and slot of a peer that stops reading a buffered response' do
    stub_const("#{described_class}::RESPONSE_WRITE_TIMEOUT", 0.3)
    File.binwrite(File.join(@root, 'index.html'), 'x' * body_bytes)
    server = build_server.start
    stalled = stall(server, '/', cookie: authenticate(server))

    wait_for_release(server, 3)
    expect(server.instance_variable_get(:@client_sockets)).to be_empty
  ensure
    stalled&.close
    server&.stop
  end

  it 'still delivers a whole response to a peer that reads it' do
    images = File.join(@root, 'images')
    Dir.mkdir(images)
    bytes = Random.new(11).bytes((3 * described_class::RESPONSE_CHUNK_BYTES) + 17)
    File.binwrite(File.join(images, 'odd.png'), bytes)
    files = Lich::WebUI::FileService.new(application_roots: [@root])
    files.register('odd', images, owner: Object.new)
    server = build_server(file_service: files).start
    socket = TCPSocket.new(server.host, server.port)
    socket.write(request_lines(server, '/files/odd/odd.png', ["Cookie: #{authenticate(server)}"]))

    head, body = Timeout.timeout(3) { socket.read }.split("\r\n\r\n", 2)
    expect(head).to start_with('HTTP/1.1 200 OK')
    expect(head).to include("Content-Length: #{bytes.bytesize}")
    expect(body.b).to eq(bytes)
  ensure
    socket&.close
    server&.stop
  end
end
