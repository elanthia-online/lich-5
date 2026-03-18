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
          raw = socket.gets
          JSON.parse(raw.to_s, symbolize_names: true)
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
      end
    end
  end
end
