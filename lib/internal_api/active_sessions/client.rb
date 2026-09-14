# frozen_string_literal: true

require 'json'
require 'socket'

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
        # @param socket_factory [#call] builds a connected client socket
        # @return [void]
        def initialize(host:, port:, auth_token:, socket_factory: nil)
          @host = host
          @port = port
          @auth_token = auth_token
          @socket_factory = socket_factory || ->(connect_host, connect_port) { TCPSocket.new(connect_host, connect_port) }
        end

        # Sends a raw command payload to the active sessions service.
        #
        # @param command [String] protocol command name
        # @param payload [Hash] request-specific payload
        # @return [Hash] parsed response payload or a normalized error hash
        def request(command, payload = {})
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
