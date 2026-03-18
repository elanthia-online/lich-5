# frozen_string_literal: true

require 'json'
require 'socket'

module Lich
  module InternalAPI
    module ActiveSessions
      # Thin JSON client for the local active sessions service.
      class Client
        # @param host [String]
        # @param port [Integer]
        # @param timeout [Numeric]
        # @param socket_factory [#call] builds a connected client socket
        def initialize(host:, port:, timeout: 0.5, socket_factory: nil)
          @host = host
          @port = port
          @timeout = timeout
          @socket_factory = socket_factory || ->(connect_host, connect_port) { TCPSocket.new(connect_host, connect_port) }
        end

        # Sends a raw command payload to the active sessions service.
        #
        # @param command [String]
        # @param payload [Hash]
        # @return [Hash]
        def request(command, payload = {})
          socket = @socket_factory.call(@host, @port)
          socket.write(JSON.dump(command: command, payload: payload) + "\n")
          raw = socket.gets
          JSON.parse(raw.to_s, symbolize_names: true)
        rescue StandardError => e
          { ok: false, error: e.message }
        ensure
          socket&.close rescue nil
        end

        # @return [Boolean]
        def ping
          request('ping').fetch(:ok, false)
        end

        # @param payload [Hash]
        # @return [Hash]
        def upsert(payload)
          request('upsert', payload)
        end

        # @param pid [Integer]
        # @return [Hash]
        def remove(pid)
          request('remove', pid: pid)
        end

        # @return [Hash]
        def snapshot
          request('snapshot')
        end
      end
    end
  end
end
