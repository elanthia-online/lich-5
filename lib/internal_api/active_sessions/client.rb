# frozen_string_literal: true

require 'json'
require 'socket'
require 'ipaddr'

require_relative 'bounded_frame'

module Lich
  module InternalAPI
    module ActiveSessions
      # Thin JSON client for the local active sessions service.
      #
      # The client intentionally knows nothing about lifecycle semantics. It is
      # only responsible for packaging JSON commands, reading JSON responses,
      # and normalizing failures into a predictable `{ ok: false, error: ... }`
      # shape for higher-level callers.
      class Client
        # Maximum number of seconds to wait for a server response before
        # treating the request as failed.
        #
        # @return [Numeric]
        READ_TIMEOUT = 1

        # @param host [String]
        # @param port [Integer]
        # @param auth_token [String]
        # @param socket_factory [#call] builds a connected client socket; in
        #   bounded mode must honor the supplied absolute monotonic deadline:
        #   keyword and close any socket it cannot return
        # @param max_frame_bytes [Integer, nil] optional request/response byte cap
        # @param timeout [Numeric, nil] total connect/write/read deadline seconds
        # @return [void]
        def initialize(host:, port:, auth_token:, socket_factory: nil, max_frame_bytes: nil, timeout: nil)
          @host = host
          @port = port
          @auth_token = auth_token
          @bounded = !max_frame_bytes.nil? || !timeout.nil?
          @max_frame_bytes = max_frame_bytes.nil? ? BoundedFrame::DEFAULT_MAX_BYTES : max_frame_bytes
          @timeout = timeout.nil? ? READ_TIMEOUT : timeout
          BoundedFrame.validate!(@timeout, @max_frame_bytes) if @bounded
          @socket_factory = socket_factory || (@bounded ? method(:connect_bounded) : ->(connect_host, connect_port) { TCPSocket.new(connect_host, connect_port) })
        end

        # Sends a raw command payload to the active sessions service.
        #
        # @param command [String] protocol command name
        # @param payload [Hash] request-specific payload
        # @return [Hash] parsed response payload or a normalized error hash
        def request(command, payload = {})
          return bounded_request(command, payload) if @bounded

          socket = @socket_factory.call(@host, @port)
          socket.write(JSON.dump(command: command, auth: @auth_token, payload: payload) + "\n")
          raw = read_response(socket)
          return { ok: false, error: 'read timeout' } unless raw

          response = JSON.parse(raw.to_s, symbolize_names: true)
          return { ok: false, error: 'invalid response type' } unless response.is_a?(Hash)

          response
        rescue StandardError => e
          { ok: false, error: e.message }
        ensure
          socket&.close rescue nil
        end

        # Sends a lightweight health probe to the service.
        #
        # @return [Boolean] true when the service responds with `ok: true`
        def ping
          request('ping').fetch(:ok, false)
        end

        # Registers or updates a session over the transport.
        #
        # @param payload [Hash]
        # @return [Hash]
        def upsert(payload)
          request('upsert', payload)
        end

        # Removes a session by pid over the transport.
        #
        # @param pid [Integer]
        # @return [Hash]
        def remove(pid)
          request('remove', pid: pid)
        end

        # Requests the current active sessions snapshot.
        #
        # @return [Hash]
        def snapshot
          request('snapshot')
        end

        private

        # Connects only to a numeric address, avoiding unbounded DNS resolution.
        # Coordination supplies a loopback address; legacy hostname support is
        # unchanged when bounds are absent.
        # @param host [String] numeric IP address
        # @param port [Integer] TCP port
        # @param deadline [Numeric] absolute local monotonic deadline
        # @return [Socket] connected socket
        def connect_bounded(host, port, deadline:)
          address = Addrinfo.tcp(IPAddr.new(host).to_s, port)
          socket = Socket.new(address.afamily, Socket::SOCK_STREAM, 0)
          result = socket.connect_nonblock(address, exception: false)
          if result == :wait_writable
            raise IOError, 'transport timeout' unless IO.select(nil, [socket], nil, BoundedFrame.remaining(deadline))

            error = socket.getsockopt(Socket::SOL_SOCKET, Socket::SO_ERROR).int
            raise SystemCallError.new('connect', error) unless error.zero?
          end
          BoundedFrame.remaining(deadline)
          socket
        rescue StandardError
          socket&.close rescue nil
          raise
        end

        # Sends one request with a deadline shared by connection, write and read.
        # @param command [String] protocol command
        # @param payload [Hash] request data
        # @return [Hash] protocol response or normalized error
        def bounded_request(command, payload)
          deadline = BoundedFrame.now + @timeout
          frame = JSON.dump(command: command, auth: @auth_token, payload: payload) + "\n"
          raise IOError, 'frame too large' if frame.bytesize > @max_frame_bytes

          socket = @socket_factory.call(@host, @port, deadline: deadline)
          BoundedFrame.write(socket, frame, deadline: deadline, max_bytes: @max_frame_bytes)
          raw = BoundedFrame.read(socket, deadline: deadline, max_bytes: @max_frame_bytes)
          response = JSON.parse(raw, symbolize_names: true, max_nesting: 16)
          return { ok: false, error: 'invalid response type' } unless response.is_a?(Hash)

          response
        rescue StandardError => e
          { ok: false, error: e.message }
        ensure
          socket&.close rescue nil
        end

        # Reads a single newline-terminated JSON response without allowing
        # partial frames to block indefinitely.
        #
        # @param socket [IO]
        # @return [String, nil]
        def read_response(socket)
          deadline = Time.now + READ_TIMEOUT
          buffer = +''

          loop do
            remaining = deadline - Time.now
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
      end
    end
  end
end
