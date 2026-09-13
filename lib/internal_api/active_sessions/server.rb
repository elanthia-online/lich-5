# frozen_string_literal: true

require 'json'
require 'socket'

require_relative '../../common/shutdown_log'
require_relative 'bounded_frame'

module Lich
  module InternalAPI
    module ActiveSessions
      # Read-only/query plus lifecycle write server for the active sessions API.
      #
      # The transport is intentionally local-only TCP to keep behavior consistent
      # across Linux, macOS, and Windows. The server delegates all state changes
      # to {Registry}; it does not own lifecycle policy beyond request routing
      # and thread cleanup.
      class Server
        # Maximum number of seconds to wait for the first request line from a
        # connected client before abandoning the handler.
        #
        # @return [Numeric]
        READ_TIMEOUT = 1

        attr_reader :host, :port
        attr_reader :auth_token

        # @param host [String]
        # @param port [Integer]
        # @param registry [Lich::InternalAPI::ActiveSessions::Registry]
        # @param auth_token [String] shared secret required by all clients
        # @param server_factory [#call] builds a listening server
        # @param accept_thread_factory [#call] builds the accept-loop thread
        # @param client_thread_factory [#call] builds per-client threads
        # @param request_handler [#call, nil] optional authenticated request router;
        #   must return a JSON response without blocking or performing game I/O
        # @param max_frame_bytes [Integer, nil] optional request/response byte cap
        # @param max_clients [Integer, nil] optional simultaneous client cap
        # @param timeout [Numeric, nil] total read/write deadline in seconds;
        #   enables bounded transport, as does either cap
        # @return [void]
        def initialize(host:, port:, registry:, auth_token:, server_factory: nil, accept_thread_factory: nil, client_thread_factory: nil,
                       request_handler: nil, max_frame_bytes: nil, max_clients: nil, timeout: nil)
          @host = host
          @port = port
          @registry = registry
          @auth_token = auth_token
          @request_handler = request_handler
          @bounded = !max_frame_bytes.nil? || !max_clients.nil? || !timeout.nil?
          @max_frame_bytes = max_frame_bytes.nil? ? BoundedFrame::DEFAULT_MAX_BYTES : max_frame_bytes
          @timeout = timeout.nil? ? READ_TIMEOUT : timeout
          @max_clients = max_clients
          BoundedFrame.validate!(@timeout, @max_frame_bytes) if @bounded
          if !max_clients.nil? && (!max_clients.is_a?(Integer) || !max_clients.positive?)
            raise ArgumentError, 'max_clients must be a positive integer'
          end
          @server_factory = server_factory || ->(bind_host, bind_port) { TCPServer.new(bind_host, bind_port) }
          @accept_thread_factory = accept_thread_factory || ->(&block) { Thread.new(&block) }
          @client_thread_factory = client_thread_factory || ->(socket, &block) { Thread.new(socket, &block) }
          @server = nil
          @thread = nil
          @mutex = Mutex.new
          @client_threads = []
          @client_sockets = {}
          @stopping = false
        end

        # Starts the TCP server and accept loop.
        #
        # @return [Boolean] true when the server is available for requests
        def start
          @mutex.synchronize do
            return true if running?

            @stopping = false
            @server = @server_factory.call(@host, @port)
            @server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1) rescue nil
            @port = @server.addr[1]
            @thread = @accept_thread_factory.call do
              Lich.log("info: ActiveSessions accept thread started pid=#{Process.pid} port=#{@port}") if defined?(Lich) && Lich.respond_to?(:log)
              accept_loop
            end
          end
          true
        rescue StandardError
          stop
          false
        end

        # Stops the server and its accept thread.
        #
        # Client handler threads are joined with a short timeout so shutdown
        # does not leak long-lived handler threads when the owning process exits.
        #
        # @return [void]
        def stop
          thread = nil
          server = nil
          client_threads = []
          client_sockets = []
          @mutex.synchronize do
            thread = @thread
            server = @server
            client_threads = @client_threads.dup
            @client_threads.clear
            client_sockets = @client_sockets.keys
            @client_sockets.clear
            @stopping = true
            @thread = nil
            @server = nil
          end

          server&.close rescue nil
          client_sockets.each { |socket| socket.close rescue nil }
          if thread&.alive?
            thread.join(0.1)
            thread.kill if thread.alive?
          end
          shutdown_deadline = BoundedFrame.now + 0.25 if @bounded
          client_threads.each do |client_thread|
            next unless client_thread.respond_to?(:join)

            wait = @bounded ? [shutdown_deadline - BoundedFrame.now, 0].max : 0.25
            client_thread.join(wait)
            client_thread.kill if client_thread.respond_to?(:alive?) && client_thread.alive?
          end
        end

        # Indicates whether the server thread is active.
        #
        # @return [Boolean]
        def running?
          @thread&.alive? || false
        end

        private

        # Accepts inbound socket connections and dispatches each client to its
        # own handler thread.
        #
        # Individual accept/dispatch errors are logged and retried so that a
        # transient failure does not kill the thread and leave the TCPServer
        # socket bound but unserviceable (zombie server).
        #
        # @return [void]
        def accept_loop
          loop do
            server = @server
            unless server
              unless stopping?
                Lich.log("warning: ActiveSessions accept_loop exiting: @server is nil pid=#{Process.pid}") if defined?(Lich) && Lich.respond_to?(:log)
              end
              break
            end

            socket = nil
            begin
              socket = server.accept
              if @bounded
                dispatch_bounded_client(socket)
              else
                client_thread = @client_thread_factory.call(socket) { |client| handle_tracked_client(client) }
                track_client_thread(client_thread)
              end
            rescue IOError, Errno::EBADF => e
              Lich.log("warning: ActiveSessions accept_loop closed unexpectedly: #{e.class} pid=#{Process.pid}") if !stopping? && defined?(Lich) && Lich.respond_to?(:log)
              break
            rescue StandardError => e
              socket&.close rescue nil
              Lich.log("warning: ActiveSessions accept_loop error (continuing): #{e.class}: #{e.message}") if defined?(Lich) && Lich.respond_to?(:log)
            end
          end
        rescue StandardError => e
          Lich.log("error: ActiveSessions accept_loop fatal: #{e.class}: #{e.message}\n\t#{e.backtrace&.first(5)&.join("\n\t")}") if defined?(Lich) && Lich.respond_to?(:log)
        ensure
          if defined?(Lich) && Lich.respond_to?(:log)
            if stopping?
              Lich::Common::ShutdownLog.info("ActiveSessions accept_loop stopped pid=#{Process.pid}")
            else
              Lich.log("warning: ActiveSessions accept_loop thread exiting pid=#{Process.pid}")
            end
          end
        end

        # Reserves capacity before spawning so unfinished thread creation counts
        # toward the cap. Shutdown closes even reserved, not-yet-started sockets.
        # @param socket [IO] accepted client
        # @return [void]
        def dispatch_bounded_client(socket)
          admitted = @mutex.synchronize do
            next false if @stopping || (@max_clients && @client_sockets.size >= @max_clients)

            @client_sockets[socket] = nil
            true
          end
          unless admitted
            socket.close rescue nil
            return
          end

          thread = @client_thread_factory.call(socket) do |client|
            handle_client(client) unless stopping?
          ensure
            client.close rescue nil
            @mutex.synchronize do
              @client_sockets.delete(client)
              @client_threads.delete(Thread.current)
            end
          end
          stopped = @mutex.synchronize do
            if @stopping
              true
            elsif @client_sockets.key?(socket)
              @client_sockets[socket] = thread
              @client_threads << thread
              false
            end
          end
          thread.kill if stopped && thread&.alive?
        rescue StandardError
          @mutex.synchronize { @client_sockets.delete(socket) }
          socket.close rescue nil
          raise
        end

        # Wraps client handling so finished client threads can be removed from
        # the tracked thread set regardless of request outcome.
        #
        # @param socket [IO]
        # @return [void]
        def handle_tracked_client(socket)
          handle_client(socket)
        ensure
          untrack_current_thread
        end
        private :handle_tracked_client

        # Processes a single connected client socket.
        #
        # @param socket [IO]
        # @return [void]
        def handle_client(socket)
          return handle_bounded_client(socket) if @bounded

          raw = read_request(socket)
          unless raw
            Lich.log('warning: ActiveSessions client read timed out') if defined?(Lich) && Lich.respond_to?(:log)
            return
          end

          response = process_request(raw)
          socket.puts(JSON.dump(response))
        rescue StandardError => e
          unless @bounded
            socket.puts(JSON.dump(ok: false, error: e.message)) rescue nil
          end
        ensure
          socket.close rescue nil
        end

        # Runs one bounded exchange. Failed writes are never retried with a
        # blocking error response. JSON parsing uses a depth cap of 16.
        # @param socket [IO] accepted client
        # @return [void]
        def handle_bounded_client(socket)
          deadline = BoundedFrame.now + @timeout
          raw = BoundedFrame.read(socket, deadline: deadline, max_bytes: @max_frame_bytes)
          response = process_request(raw)
          BoundedFrame.write(socket, JSON.dump(response) + "\n", deadline: deadline, max_bytes: @max_frame_bytes)
        rescue StandardError
          nil
        ensure
          socket.close rescue nil
        end

        # Reads a single newline-terminated request using a deadline-driven
        # nonblocking loop so partial writes cannot hang the handler thread.
        #
        # @param socket [IO]
        # @return [String, nil]
        def read_request(socket)
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + READ_TIMEOUT
          buffer = +''

          loop do
            remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
            return nil if remaining <= 0
            return nil unless IO.select([socket], nil, nil, remaining)

            chunk = socket.read_nonblock(1024, exception: false)
            case chunk
            when :wait_readable
              next
            when nil
              break
            else
              buffer << chunk
              break if buffer.include?("\n")
            end
          end

          buffer.empty? ? nil : buffer
        rescue IO::WaitReadable
          nil
        end
        private :read_request

        # Parses and routes a single JSON request.
        #
        # @param raw [String, nil] one request line encoded as JSON
        # @return [Hash] normalized protocol response
        def process_request(raw)
          request = JSON.parse(raw.to_s, symbolize_names: true, max_nesting: @bounded ? 16 : 100)
          return { ok: false, error: 'invalid request type' } unless request.is_a?(Hash)
          return unauthorized_response unless authorized?(request)
          return @request_handler.call(request) if @request_handler

          case request[:command]
          when 'ping'
            { ok: true, payload: { status: 'ok' } }
          when 'upsert'
            { ok: true, payload: @registry.upsert(request.fetch(:payload)) }
          when 'remove'
            remove_pid = request[:pid] || request.fetch(:payload, {})[:pid]
            return { ok: false, error: 'pid required' } if remove_pid.nil? || remove_pid.to_s.empty?

            { ok: true, payload: { removed: @registry.remove(remove_pid) } }
          when 'snapshot'
            { ok: true, payload: @registry.snapshot }
          else
            { ok: false, error: "unknown command: #{request[:command]}" }
          end
        rescue StandardError => e
          { ok: false, error: e.message }
        end

        def authorized?(request)
          request[:auth].to_s == @auth_token
        end
        private :authorized?

        def unauthorized_response
          Lich.log('warning: ActiveSessions unauthorized local request rejected') if defined?(Lich) && Lich.respond_to?(:log)
          { ok: false, error: 'unauthorized' }
        end
        private :unauthorized_response

        # Records a spawned client handler thread for later shutdown cleanup.
        #
        # @param thread [Thread, nil]
        # @return [void]
        def track_client_thread(thread)
          return unless thread

          @mutex.synchronize { @client_threads << thread }
        end
        private :track_client_thread

        # Removes the current handler thread from the tracked thread set.
        #
        # @return [void]
        def untrack_current_thread
          @mutex.synchronize { @client_threads.delete(Thread.current) }
        end
        private :untrack_current_thread

        def stopping?
          return @stopping if @mutex.owned?

          @mutex.synchronize { @stopping }
        end
        private :stopping?
      end
    end
  end
end
