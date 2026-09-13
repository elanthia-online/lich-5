# frozen_string_literal: true

require_relative '../../../spec_helper'
require_relative '../../../../lib/internal_api/active_sessions/server'
require_relative '../../../../lib/internal_api/active_sessions/client'

RSpec.describe 'Optional bounded ActiveSessions transport' do
  let(:server_class) { Lich::InternalAPI::ActiveSessions::Server }
  let(:client_class) { Lich::InternalAPI::ActiveSessions::Client }
  let(:frame) { Lich::InternalAPI::ActiveSessions::BoundedFrame }

  after do
    @sockets&.each { |socket| socket.close rescue nil }
    @server&.stop
    @worker&.kill
    @listener&.close
  end

  # @param options [Hash] server constructor overrides
  # @return [Lich::InternalAPI::ActiveSessions::Server]
  def start_server(**options)
    @server = server_class.new(host: '127.0.0.1', port: 0, registry: nil,
                               auth_token: 'secret', max_frame_bytes: 1024,
                               max_clients: 2, timeout: 0.15, **options)
    expect(@server.start).to be(true)
    @server
  end

  # @return [TCPSocket] connected socket tracked for cleanup
  def connect
    socket = TCPSocket.new('127.0.0.1', @server.port)
    (@sockets ||= []) << socket
    socket
  end

  # @param block [Proc] condition to await within a fixed deadline
  # @return [void]
  def await(&block)
    deadline = frame.now + 1
    until block.call
      raise 'condition timed out' if frame.now >= deadline

      sleep 0.005
    end
  end

  # @return [Integer] active or reserved client count
  def client_count
    @server.instance_variable_get(:@mutex).synchronize do
      @server.instance_variable_get(:@client_sockets).size
    end
  end

  it 'routes authenticated requests exclusively through the optional handler' do
    handler = spy('request handler')
    allow(handler).to receive(:call).and_return(ok: true, payload: { mode: 'read-only' })
    start_server(request_handler: handler)
    client = client_class.new(host: '127.0.0.1', port: @server.port, auth_token: 'secret', timeout: 0.5)
    expect(client.snapshot).to eq(ok: true, payload: { mode: 'read-only' })
    expect(handler).to have_received(:call).with(command: 'snapshot', auth: 'secret', payload: {})

    denied = client_class.new(host: '127.0.0.1', port: @server.port, auth_token: 'wrong', timeout: 0.5)
    expect(denied.snapshot).to eq(ok: false, error: 'unauthorized')
    expect(handler).to have_received(:call).once
  end

  it 'rejects oversized, non-object and excessively nested requests before routing' do
    handler = spy('request handler')
    start_server(request_handler: handler)
    requests = ["x" * 1025, "[]\n", JSON.dump(auth: 'secret', payload: Array.new(1, [[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]])) + "\n"]
    requests.each do |request|
      socket = connect
      socket.write(request)
      expect(IO.select([socket], nil, nil, 0.5)).not_to be_nil
      socket.read
    end
    expect(handler).not_to have_received(:call)
  end

  it 'expires partial frames without allowing slow arrivals to extend the deadline' do
    start_server
    socket = connect
    socket.write('{')
    started = frame.now
    await { client_count == 1 }
    sleep 0.08
    socket.write('"')
    expect(IO.select([socket], nil, nil, 0.4)).not_to be_nil
    expect(socket.read).to eq('')
    expect(frame.now - started).to be < 0.35
  end

  it 'reserves the client slot before a handler thread is created and releases it on failure' do
    entered = Queue.new
    release = Queue.new
    calls = 0
    factory = lambda do |socket, &block|
      calls += 1
      if calls == 1
        entered << true
        release.pop
        raise 'factory failed'
      end
      Thread.new(socket, &block)
    end
    start_server(max_clients: 1, client_thread_factory: factory)
    first = connect
    await { !entered.empty? }
    expect(client_count).to eq(1)
    release << true
    expect(IO.select([first], nil, nil, 0.5)).not_to be_nil
    expect(first.read).to eq('')
    second = connect
    await { client_count == 1 && calls == 2 }
    rejected = connect
    expect(IO.select([rejected], nil, nil, 0.5)).not_to be_nil
    expect(rejected.read).to eq('')
    expect(calls).to eq(2)
    second.close
    await { client_count.zero? }
  ensure
    release << true
  end

  it 'bounds a server write when the peer never reads the response' do
    factory = lambda do |socket, &block|
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDBUF, 1024)
      Thread.new(socket, &block)
    end
    start_server(max_frame_bytes: 8_000_000, client_thread_factory: factory,
                 request_handler: ->(_request) { { ok: true, payload: 'x' * 4_000_000 } })
    socket = connect
    socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVBUF, 1024)
    socket.write("{\"auth\":\"secret\",\"command\":\"snapshot\"}\n")
    await { client_count == 1 }
    started = frame.now
    await { client_count.zero? }
    expect(frame.now - started).to be < 0.6
    expect(@server.instance_variable_get(:@client_threads)).to be_empty
  end

  it 'closes reserved sockets during shutdown even before thread creation returns' do
    entered = Queue.new
    release = Queue.new
    factory = lambda do |socket, &block|
      entered << true
      release.pop
      Thread.new(socket, &block)
    end
    start_server(client_thread_factory: factory)
    socket = connect
    await { !entered.empty? }
    started = frame.now
    @server.stop
    expect(frame.now - started).to be < 0.5
    expect(IO.select([socket], nil, nil, 0.5)).not_to be_nil
    expect(socket.read).to eq('')
    expect(client_count).to eq(0)
  ensure
    release << true
  end

  it 'caps client responses and rejects incomplete frames' do
    ["x" * 1025, '{"ok":true}'].each do |response|
      @listener = TCPServer.new('127.0.0.1', 0)
      @worker = Thread.new do
        socket = @listener.accept
        socket.gets
        socket.write(response)
      ensure
        socket&.close
      end
      client = client_class.new(host: '127.0.0.1', port: @listener.addr[1], auth_token: 'secret', timeout: 0.3, max_frame_bytes: 1024)
      expect(client.snapshot).to eq(ok: false, error: response.size > 1024 ? 'frame too large' : 'incomplete frame')
      @worker.join(0.5)
      @listener.close
    end
  end

  it 'bounds client writes when the peer never reads the request' do
    @listener = TCPServer.new('127.0.0.1', 0)
    accepted = Queue.new
    @worker = Thread.new { accepted << @listener.accept }
    factory = lambda do |host, port, deadline:|
      expect(deadline).to be > frame.now
      socket = TCPSocket.new(host, port)
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDBUF, 1024)
      socket
    end
    client = client_class.new(host: '127.0.0.1', port: @listener.addr[1], auth_token: 'secret',
                              socket_factory: factory, timeout: 0.1, max_frame_bytes: 8_000_000)
    started = frame.now
    expect(client.request('snapshot', data: 'x' * 4_000_000)).to eq(ok: false, error: 'transport timeout')
    expect(frame.now - started).to be < 0.5
    await { !accepted.empty? }
    (@sockets ||= []) << accepted.pop
  end

  it 'uses the same client deadline for connect, write, and response waits' do
    socket = instance_double(Socket, close: nil)
    observed = []
    factory = lambda do |_host, _port, deadline:|
      observed << deadline
      socket
    end
    allow(frame).to receive(:write) { |_socket, _request, deadline:, **_options| observed << deadline }
    allow(frame).to receive(:read) do |_socket, deadline:, **_options|
      observed << deadline
      "{\"ok\":true}\n"
    end
    client = client_class.new(host: '127.0.0.1', port: 1, auth_token: 'secret', timeout: 0.2, socket_factory: factory)
    expect(client.ping).to be(true)
    expect(observed.size).to eq(3)
    expect(observed.uniq.size).to eq(1)
    expect(socket).to have_received(:close)
  end

  it 'closes a socket when the nonblocking connection exceeds its deadline' do
    socket = instance_double(Socket, connect_nonblock: :wait_writable, close: nil)
    allow(Socket).to receive(:new).and_return(socket)
    allow(IO).to receive(:select).with(nil, [socket], nil, kind_of(Numeric)).and_return(nil)
    expect(socket).not_to receive(:write_nonblock)
    client = client_class.new(host: '127.0.0.1', port: 1, auth_token: 'secret', timeout: 0.2)

    expect(client.snapshot).to eq(ok: false, error: 'transport timeout')
    expect(socket).to have_received(:close)
  end

  it 'rejects a failed nonblocking connection before attempting a request' do
    socket = instance_double(Socket, connect_nonblock: :wait_writable, close: nil)
    allow(Socket).to receive(:new).and_return(socket)
    allow(IO).to receive(:select).and_return([socket])
    allow(socket).to receive(:getsockopt)
      .with(Socket::SOL_SOCKET, Socket::SO_ERROR)
      .and_return(instance_double(Socket::Option, int: Errno::ECONNREFUSED::Errno))
    expect(socket).not_to receive(:write_nonblock)
    client = client_class.new(host: '127.0.0.1', port: 1, auth_token: 'secret', timeout: 0.2)

    expect(client.snapshot).to include(ok: false, error: a_string_matching(/refused/i))
    expect(socket).to have_received(:close)
  end

  it 'refuses oversized outgoing requests without opening a connection' do
    factory = spy('socket factory')
    client = client_class.new(host: '127.0.0.1', port: 1, auth_token: 'secret',
                              timeout: 0.2, max_frame_bytes: 64, socket_factory: factory)
    expect(client.request('snapshot', data: 'x' * 65)).to eq(ok: false, error: 'frame too large')
    expect(factory).not_to have_received(:call)
  end

  it 'rejects invalid bounds before opening sockets' do
    [0, -1, Float::INFINITY, Float::NAN, '1', false].each do |timeout|
      expect { client_class.new(host: '127.0.0.1', port: 1, auth_token: 'secret', timeout: timeout) }.to raise_error(ArgumentError)
    end
    [0, -1, 0.5, false].each do |max_bytes|
      expect { client_class.new(host: '127.0.0.1', port: 1, auth_token: 'secret', max_frame_bytes: max_bytes) }.to raise_error(ArgumentError)
    end
    expect { server_class.new(host: '127.0.0.1', port: 0, registry: nil, auth_token: 'secret', max_clients: 0) }.to raise_error(ArgumentError)
  end
end
