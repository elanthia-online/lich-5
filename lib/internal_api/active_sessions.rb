# frozen_string_literal: true

require_relative 'active_sessions/registry'
require_relative 'active_sessions/server'
require_relative 'active_sessions/client'
require_relative 'active_sessions/lifecycle'

module Lich
  module InternalAPI
    # Cross-process local service that tracks currently active Lich sessions.
    module ActiveSessions
      FEATURE_FLAG = :active_sessions_api
      DEFAULT_HOST = '127.0.0.1'
      DEFAULT_PORT = 42_857

      @registry = nil
      @server = nil
      @client = nil
      @mutex = Mutex.new

      # Indicates whether the active sessions API is enabled.
      #
      # Until feature-flag plumbing is present in core, this API remains safely
      # dormant and returns empty snapshots.
      #
      # @return [Boolean]
      def self.enabled?
        return false unless defined?(Lich::Common::FeatureFlags)

        Lich::Common::FeatureFlags.enabled?(FEATURE_FLAG)
      rescue StandardError => e
        Lich.log("warning: ActiveSessions feature flag check failed: #{e.class}: #{e.message}") if Lich.respond_to?(:log)
        false
      end

      # Starts the local service if no healthy service is already responding.
      #
      # @return [Boolean]
      def self.ensure_service!
        return false unless enabled?

        return true if client.ping

        @mutex.synchronize do
          return true if client.ping

          @registry ||= Registry.new
          @server ||= Server.new(host: DEFAULT_HOST, port: DEFAULT_PORT, registry: @registry)
          @server.start
        end
      rescue StandardError => e
        Lich.log("warning: ActiveSessions service unavailable: #{e.class}: #{e.message}") if Lich.respond_to?(:log)
        false
      end

      # Registers or updates a session record in the local service.
      #
      # @param payload [Hash]
      # @return [Boolean]
      def self.register_session(payload)
        return false unless enabled?
        return false unless ensure_service!

        client.upsert(payload).fetch(:ok, false)
      end

      # Removes a session record by pid.
      #
      # @param pid [Integer]
      # @return [Boolean]
      def self.unregister_session(pid:)
        return false unless enabled?
        return false unless ensure_service!

        client.remove(pid).fetch(:ok, false)
      end

      # Returns the current active sessions snapshot.
      #
      # @return [Hash]
      def self.snapshot
        return fallback_snapshot unless enabled?
        return fallback_snapshot unless ensure_service!

        response = client.snapshot
        return fallback_snapshot(error: response[:error]) unless response[:ok]

        response[:payload]
      rescue StandardError => e
        fallback_snapshot(error: e.message)
      end

      # Stops the in-process server if this process owns one.
      #
      # @return [void]
      def self.stop_service!
        @mutex.synchronize do
          @server&.stop
          @server = nil
          @registry = nil
          @client = nil
        end
      end

      # @return [Lich::InternalAPI::ActiveSessions::Client]
      def self.client
        @client ||= Client.new(host: DEFAULT_HOST, port: DEFAULT_PORT)
      end
      private_class_method :client

      # @param error [String, nil]
      # @return [Hash]
      def self.fallback_snapshot(error: nil)
        {
          source: 'ActiveSessionsAPI',
          total: 0,
          connected: 0,
          detachable: 0,
          sessions: [],
          error: error
        }.compact
      end
      private_class_method :fallback_snapshot
    end
  end
end
