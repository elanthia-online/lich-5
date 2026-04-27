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
  let(:finished_thread) { instance_double(Thread, alive?: false, join: nil) }

  # Builds a Server whose accept loop runs synchronously in the calling
  # thread so specs control exactly how many iterations execute.
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

    default_client_factory = ->(socket, &block) do
      block&.call(socket)
      finished_thread
    end

    described_class.new(
      host: '127.0.0.1',
      port: 0,
      registry: registry,
      auth_token: 'test-token',
      server_factory: ->(_h, _p) { listener },
      accept_thread_factory: ->(&block) do
        block.call
        instance_double(Thread, alive?: false, join: nil, kill: nil)
      end,
      client_thread_factory: client_thread_factory || default_client_factory
    )
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
        server.start

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
        server.start

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
            finished_thread
          end
        )
        server.start

        expect(leaked_socket).to have_received(:close).at_least(:once)
        expect(good_socket).to have_received(:puts).with(a_string_including('"ok":true'))
      ensure
        server&.stop
      end
    end

    context 'when accept raises before returning a socket' do
      it 'does not attempt to close a nil socket' do
        server = build_server(accept_results: [RuntimeError, IOError])

        expect { server.start }.not_to raise_error
      ensure
        server&.stop
      end
    end

    context 'when server.accept raises IOError' do
      it 'breaks the loop without logging' do
        server = build_server(accept_results: [IOError])

        expect(Lich).not_to receive(:log)
        server.start
      ensure
        server&.stop
      end
    end

    context 'when server.accept raises Errno::EBADF' do
      it 'breaks the loop without logging' do
        server = build_server(accept_results: [Errno::EBADF])

        expect(Lich).not_to receive(:log)
        server.start
      ensure
        server&.stop
      end
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
