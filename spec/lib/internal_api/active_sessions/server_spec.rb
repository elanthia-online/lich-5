# frozen_string_literal: true

# Adversarial specs for Lich::InternalAPI::ActiveSessions::Server.
#
# Verifies that transient errors in the accept loop do not kill the
# thread and leave the TCPServer socket bound but unserviceable.
# All tests use injected factory doubles so no real TCP ports are bound.

require_relative '../../../spec_helper'
require_relative '../../../../lib/internal_api/active_sessions/registry'
require_relative '../../../../lib/internal_api/active_sessions/server'

RSpec.describe Lich::InternalAPI::ActiveSessions::Server do
  let(:registry) { instance_double(Lich::InternalAPI::ActiveSessions::Registry) }
  let(:listener) do
    instance_double(
      TCPServer,
      addr: ['AF_INET', 41_234, '127.0.0.1', '127.0.0.1'],
      setsockopt: 0,
      close: nil
    )
  end

  # Builds a Server with a finite, injected sequence of accept results.
  #
  # @param accept_results [Array] sequence for listener.accept; each entry
  #   is a socket double or an exception class to raise
  # @param client_thread_factory [Proc, nil] override for thread spawning
  # @return [Lich::InternalAPI::ActiveSessions::Server]
  def build_server(accept_results:, client_thread_factory: nil)
    call_count = 0
    allow(listener).to receive(:accept) do
      entry = accept_results[call_count]
      call_count += 1
      entry.is_a?(Class) ? raise(entry, "simulated #{entry}") : entry
    end

    # Keep accept-error examples synchronous; lifecycle examples inject real threads.
    default_client_factory = ->(socket, &block) do
      block&.call(socket)
    end

    described_class.new(
      host: '127.0.0.1',
      port: 0,
      registry: registry,
      auth_token: 'test-token',
      server_factory: ->(_h, _p) { listener },
      accept_thread_factory: ->(&block) { Thread.new(&block) },
      client_thread_factory: client_thread_factory || default_client_factory
    )
  end

  # Runs the finite accept loop through the real start/registration boundary.
  #
  # @param server [Lich::InternalAPI::ActiveSessions::Server]
  # @return [void]
  def start_and_finish(server)
    server.start
    raise 'accept loop did not finish' unless server.instance_variable_get(:@thread).join(2)
  end

  # Stubs a socket double to respond to a ping request.
  #
  # @param socket [IO] instance double
  # @return [void]
  def stub_ping_socket(socket)
    allow(socket).to receive(:read_nonblock)
      .and_return("{\"command\":\"ping\",\"auth\":\"test-token\"}\n")
    allow(socket).to receive(:puts)
    allow(socket).to receive(:close)
    allow(IO).to receive(:select).and_return([socket])
  end

  describe '#accept_loop' do
    context 'with a single transient StandardError from server.accept' do
      let(:good_socket) { instance_double(IO) }

      before { stub_ping_socket(good_socket) }

      it 'logs the error and continues accepting the next connection' do
        server = build_server(accept_results: [RuntimeError, good_socket, IOError])
        start_and_finish(server)

        expect(good_socket).to have_received(:puts).with(a_string_including('"ok":true'))
      ensure
        server&.stop
      end
    end

    context 'with multiple consecutive transient errors' do
      let(:good_socket) { instance_double(IO) }

      before { stub_ping_socket(good_socket) }

      it 'survives all of them and processes the next valid connection' do
        server = build_server(
          accept_results: [RuntimeError, ArgumentError, Errno::ENOMEM, good_socket, IOError]
        )
        start_and_finish(server)

        expect(good_socket).to have_received(:puts).with(a_string_including('"ok":true'))
      ensure
        server&.stop
      end
    end

    context 'when the client thread factory raises after accept succeeds' do
      let(:leaked_socket) { instance_double(IO) }
      let(:good_socket) { instance_double(IO) }

      before do
        allow(leaked_socket).to receive(:close)
        stub_ping_socket(good_socket)
      end

      it 'closes the leaked socket and recovers to process the next connection' do
        server = build_server(
          accept_results: [leaked_socket, good_socket, IOError],
          client_thread_factory: ->(socket, &block) do
            raise 'thread pool exhausted' if socket.equal?(leaked_socket)

            block&.call(socket)
          end
        )
        start_and_finish(server)

        expect(leaked_socket).to have_received(:close).at_least(:once)
        expect(good_socket).to have_received(:puts).with(a_string_including('"ok":true'))
      ensure
        server&.stop
      end
    end

    context 'when accept raises before returning a socket' do
      it 'does not attempt to close a nil socket' do
        server = build_server(accept_results: [RuntimeError, IOError])

        expect { start_and_finish(server) }.not_to raise_error
      ensure
        server&.stop
      end
    end

    context 'when server.accept raises IOError' do
      it 'logs the unexpected close and breaks the loop' do
        server = build_server(accept_results: [IOError])

        allow(Lich).to receive(:log)
        start_and_finish(server)

        expect(Lich).to have_received(:log).with(/ActiveSessions accept_loop closed unexpectedly: IOError/)
        expect(Lich).to have_received(:log).with(/ActiveSessions accept_loop thread exiting/)
      ensure
        server&.stop
      end
    end

    context 'when server.accept raises Errno::EBADF' do
      it 'logs the unexpected close and breaks the loop' do
        server = build_server(accept_results: [Errno::EBADF])

        allow(Lich).to receive(:log)
        start_and_finish(server)

        expect(Lich).to have_received(:log).with(/ActiveSessions accept_loop closed unexpectedly: Errno::EBADF/)
        expect(Lich).to have_received(:log).with(/ActiveSessions accept_loop thread exiting/)
      ensure
        server&.stop
      end
    end

    context 'when server.accept raises during intentional stop' do
      it 'logs a clean stopped message without warning' do
        server = described_class.new(
          host: '127.0.0.1',
          port: 0,
          registry: registry,
          auth_token: 'test-token',
          server_factory: ->(_h, _p) { listener }
        )
        allow(listener).to receive(:accept).and_raise(IOError, 'closed')
        allow(Lich).to receive(:log)

        server.instance_variable_set(:@server, listener)
        server.instance_variable_set(:@stopping, true)
        server.send(:accept_loop, server.instance_variable_get(:@run_id))

        expect(Lich).to have_received(:log).with(/ActiveSessions accept_loop stopped/)
        expect(Lich).not_to have_received(:log).with(/closed unexpectedly/)
        expect(Lich).not_to have_received(:log).with(/thread exiting/)
      end
    end
  end

  describe 'handler tracking' do
    it 'removes real handlers that finish before their factory returns' do
      sockets = Array.new(16) { instance_double(IO, close: nil) }
      handlers = []
      server = build_server(
        accept_results: sockets + [IOError],
        client_thread_factory: ->(socket, &block) do
          handler = Thread.new(socket, &block)
          handlers << handler
          raise 'handler did not finish' unless handler.join(2)

          handler
        end
      )
      allow(server).to receive(:handle_client) do |socket|
        expect(server.instance_variable_get(:@client_threads)).to include(Thread.current)
        socket.close
      end

      start_and_finish(server)

      expect(handlers.size).to eq(16)
      expect(handlers).to all(satisfy { |handler| !handler.alive? })
      expect(server.instance_variable_get(:@client_threads)).to be_empty
    ensure
      server&.stop
      handlers&.each { |handler| handler.kill if handler.alive? }
    end

    it 'joins a registered handler outside the tracking mutex during shutdown' do
      entered = Queue.new
      release = Queue.new
      socket = instance_double(IO, close: nil)
      handler = nil
      server = build_server(
        accept_results: [socket, IOError],
        client_thread_factory: ->(client, &block) do
          handler = Thread.new(client, &block)
          raise 'handler did not register' unless entered.pop(timeout: 2)

          handler
        end
      )
      allow(server).to receive(:handle_client) do
        entered << true
        release.pop
      end
      start_and_finish(server)
      expect(server.instance_variable_get(:@client_threads)).to eq([handler])
      allow(handler).to receive(:join).and_call_original
      expect(handler).to receive(:join).with(0.25).and_wrap_original do |original, timeout|
        expect(server.instance_variable_get(:@mutex)).not_to be_owned
        release << true
        original.call(timeout)
      end

      server.stop

      expect(handler).not_to be_alive
      expect(server.instance_variable_get(:@client_threads)).to be_empty
    ensure
      release&.push(true)
      handler&.join(2)
      server&.stop
      handler&.kill if handler&.alive?
    end

    it 'closes a late handler socket without dispatching after shutdown' do
      release = Queue.new
      socket = instance_double(IO, close: nil)
      handler = nil
      server = build_server(
        accept_results: [socket, IOError],
        client_thread_factory: ->(client, &block) do
          handler = Thread.new do
            release.pop
            block.call(client)
          end
        end
      )
      expect(server).not_to receive(:handle_client)
      start_and_finish(server)
      server.stop

      release << true
      expect(handler.join(2)).to eq(handler)

      expect(socket).to have_received(:close).once
      expect(server.instance_variable_get(:@client_threads)).to be_empty
    ensure
      release&.push(true)
      handler&.join(2)
      server&.stop
      handler&.kill if handler&.alive?
    end

    it 'serves a delayed handler after the accept loop advances within the same run' do
      release = Queue.new
      socket = instance_double(IO)
      handler = nil
      server = build_server(
        accept_results: [socket, IOError],
        client_thread_factory: ->(client, &block) do
          handler = Thread.new do
            release.pop
            block.call(client)
          end
        end
      )
      expect(server).to receive(:handle_client).with(socket).once
      start_and_finish(server)

      release << true
      expect(handler.join(2)).to eq(handler)

      expect(server.instance_variable_get(:@client_threads)).to be_empty
    ensure
      release&.push(true)
      handler&.join(2)
      server&.stop
      handler&.kill if handler&.alive?
    end

    it 'rejects an earlier run handler after restart while serving new handlers' do
      release = Queue.new
      old_socket = instance_double(IO, close: nil)
      new_socket = instance_double(IO, close: nil)
      handlers = []
      server = build_server(
        accept_results: [old_socket, IOError, new_socket, IOError],
        client_thread_factory: ->(client, &block) do
          handler = Thread.new do
            release.pop if client.equal?(old_socket)
            block.call(client)
          end
          handlers << handler
          raise 'new handler did not finish' if client.equal?(new_socket) && !handler.join(2)

          handler
        end
      )
      expect(server).not_to receive(:handle_client).with(old_socket)
      expect(server).to receive(:handle_client).with(new_socket).once
      start_and_finish(server)
      server.stop
      start_and_finish(server)

      release << true
      expect(handlers.first.join(2)).to eq(handlers.first)

      expect(old_socket).to have_received(:close).once
      expect(server.instance_variable_get(:@client_threads)).to be_empty
    ensure
      release&.push(true)
      handlers&.each { |handler| handler.join(2) }
      server&.stop
      handlers&.each { |handler| handler.kill if handler.alive? }
    end

    it 'untracks a handler when request handling raises' do
      socket = instance_double(IO)
      server = build_server(accept_results: [IOError])
      allow(server).to receive(:handle_client).and_raise(IOError, 'request failed')
      run_id = server.instance_variable_get(:@run_id)
      handler = Thread.new do
        server.send(:handle_tracked_client, socket, run_id)
      rescue IOError => error
        error.message
      end

      expect(handler.join(2)).to eq(handler)
      expect(handler.value).to eq('request failed')
      expect(server.instance_variable_get(:@client_threads)).to be_empty
    ensure
      server&.stop
      handler&.kill if handler&.alive?
    end
  end

  describe '#running?' do
    context 'when the accept thread has exited' do
      it 'reports false so callers can detect the zombie state' do
        dead_thread = instance_double(Thread, alive?: false, join: nil, kill: nil)

        server = described_class.new(
          host: '127.0.0.1',
          port: 0,
          registry: registry,
          auth_token: 'test-token',
          server_factory: ->(_h, _p) { listener },
          accept_thread_factory: ->(&_block) { dead_thread }
        )
        server.start

        expect(server).not_to be_running
      ensure
        server&.stop
      end
    end
  end
end
