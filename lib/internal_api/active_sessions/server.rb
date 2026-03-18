# frozen_string_literal: true

require 'json'
require 'socket'

module Lich
  module InternalAPI
    module ActiveSessions
      # Read-only/query plus lifecycle write server for the active sessions API.
      #
      # The transport is intentionally local-only TCP to keep behavior consistent
      # across Linux, macOS, and Windows.
      class Server
        attr_reader :host, :port

        # @param host [String]
        # @param port [Integer]
        # @param registry [Lich::InternalAPI::ActiveSessions::Registry]
        # @param server_factory [#call] builds a listening server
        # @param accept_thread_factory [#call] builds the accept-loop thread
        # @param client_thread_factory [#call] builds per-client threads
        def initialize(host:, port:, registry:, server_factory: nil, accept_thread_factory: nil, client_thread_factory: nil)
          @host = host
          @port = port
          @registry = registry
          @server_factory = server_factory || ->(bind_host, bind_port) { TCPServer.new(bind_host, bind_port) }
          @accept_thread_factory = accept_thread_factory || ->(&block) { Thread.new(&block) }
          @client_thread_factory = client_thread_factory || ->(socket, &block) { Thread.new(socket, &block) }
          @server = nil
          @thread = nil
          @mutex = Mutex.new
        end

        # Starts the TCP server and accept loop.
        #
        # @return [Boolean]
        def start
          @mutex.synchronize do
            return true if running?

            @server = @server_factory.call(@host, @port)
            @server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1) rescue nil
            @port = @server.addr[1]
            @thread = @accept_thread_factory.call { accept_loop }
          end
          true
        rescue StandardError
          stop
          false
        end

        # Stops the server and its accept thread.
        #
        # @return [void]
        def stop
          thread = nil
          server = nil
          @mutex.synchronize do
            thread = @thread
            server = @server
            @thread = nil
            @server = nil
          end

          server&.close rescue nil
          thread&.kill if thread&.alive?
        end

        # Indicates whether the server thread is active.
        #
        # @return [Boolean]
        def running?
          @thread&.alive? || false
        end

        private

        def accept_loop
          loop do
            socket = @server.accept
            @client_thread_factory.call(socket) { |client| handle_client(client) }
          end
        rescue IOError, Errno::EBADF
          nil
        end

        def handle_client(socket)
          raw = socket.gets
          response = process_request(raw)
          socket.puts(JSON.dump(response))
        rescue StandardError => e
          socket.puts(JSON.dump(ok: false, error: e.message)) rescue nil
        ensure
          socket.close rescue nil
        end

        def process_request(raw)
          request = JSON.parse(raw.to_s, symbolize_names: true)
          case request[:command]
          when 'ping'
            { ok: true, payload: { status: 'ok' } }
          when 'upsert'
            { ok: true, payload: @registry.upsert(request.fetch(:payload)) }
          when 'remove'
            remove_pid = request[:pid] || request.fetch(:payload, {})[:pid]
            { ok: true, payload: { removed: @registry.remove(remove_pid) } }
          when 'snapshot'
            { ok: true, payload: @registry.snapshot }
          else
            { ok: false, error: "unknown command: #{request[:command]}" }
          end
        rescue StandardError => e
          { ok: false, error: e.message }
        end
      end
    end
  end
end
