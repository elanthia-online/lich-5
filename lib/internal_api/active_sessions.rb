# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'tmpdir'

require_relative 'active_sessions/registry'
require_relative 'active_sessions/server'
require_relative 'active_sessions/client'
require_relative 'active_sessions/lifecycle'

module Lich
  module InternalAPI
    # Cross-process local service that tracks currently active Lich sessions.
    #
    # This module owns the process-local server instance for the active
    # sessions API and exposes the smallest set of operations needed by the
    # lifecycle hooks:
    # - feature-gated availability checks
    # - best-effort service bootstrap
    # - session registration and removal
    # - read-only snapshot retrieval
    #
    # The service is intentionally dormant unless its feature flag is enabled.
    # When disabled, all public entry points return inert values rather than
    # raising, so feature consumers can safely probe for availability.
    module ActiveSessions
      # Feature flag name that enables the active sessions API.
      #
      # @return [Symbol]
      FEATURE_FLAG = :active_sessions_api

      # Loopback host used by the local TCP service.
      #
      # @return [String]
      DEFAULT_HOST = '127.0.0.1'

      # Default TCP port used by the local service.
      #
      # @return [Integer]
      DEFAULT_PORT = 42_857

      # Filename used to publish the current owner token for local clients.
      #
      # @return [String]
      DISCOVERY_FILENAME = 'lich-active-sessions.json'

      @registry = nil
      @server = nil
      @service_client = nil
      @service_client_token = nil
      @mutex = Mutex.new
      @service_client_mutex = Mutex.new

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
      # The first process to win startup becomes the in-process server owner.
      # All later callers reuse the same endpoint through the client adapter.
      #
      # @return [Boolean] true when a healthy service is available
      def self.ensure_service!
        return false unless enabled?

        return true if service_available?

        @mutex.synchronize do
          return true if service_available?

          @registry ||= Registry.new
          @server ||= Server.new(
            host: DEFAULT_HOST,
            port: DEFAULT_PORT,
            registry: @registry,
            auth_token: SecureRandom.hex(32)
          )
          return false unless @server.start

          write_discovery(owner_pid: Process.pid, auth_token: @server.auth_token)
          true
        end
      rescue StandardError => e
        Lich.log("warning: ActiveSessions service unavailable: #{e.class}: #{e.message}") if Lich.respond_to?(:log)
        false
      end

      # Registers or updates a session record in the local service.
      #
      # @param payload [Hash] normalized session metadata
      # @return [Boolean] true when the service accepted the update
      def self.register_session(payload)
        return false unless enabled?
        return false unless ensure_service!

        service_client&.upsert(payload)&.fetch(:ok, false) || false
      end

      # Removes a session record by pid.
      #
      # @param pid [Integer]
      # @return [Boolean] true when the service accepted the removal request
      def self.unregister_session(pid:)
        return false unless enabled?
        return false unless ensure_service!

        service_client&.remove(pid)&.fetch(:ok, false) || false
      end

      # Returns the current active sessions snapshot.
      #
      # @return [Hash] a normalized snapshot or an inert fallback payload
      def self.snapshot
        return fallback_snapshot unless enabled?
        return fallback_snapshot unless ensure_service!

        response = service_client&.snapshot || fallback_snapshot(error: 'active sessions service unavailable')
        return fallback_snapshot(error: response[:error]) unless response[:ok]

        response[:payload]
      rescue StandardError => e
        fallback_snapshot(error: e.message)
      end

      # Returns sanitized metadata about the current active-sessions service.
      #
      # The public shape intentionally omits the shared auth token while still
      # exposing enough information for diagnostics and operator visibility.
      #
      # @return [Hash]
      def self.service_info
        discovery = load_discovery
        {
          source: 'ActiveSessionsAPI',
          owner_pid: discovery[:owner_pid],
          updated_at: discovery[:updated_at],
          service_available: service_available?
        }.compact
      end

      # Stops the in-process server if this process owns one.
      #
      # This is intended for explicit service shutdown paths, not ordinary
      # lifecycle teardown for every session consumer.
      #
      # @return [void]
      def self.stop_service!
        @mutex.synchronize do
          @server&.stop
          @server = nil
          @registry = nil
        end
        @service_client_mutex.synchronize do
          @service_client = nil
          @service_client_token = nil
        end
        delete_discovery_if_owned
      end

      # Returns a client configured from the current discovery record.
      #
      # @return [Lich::InternalAPI::ActiveSessions::Client, nil]
      def self.service_client
        discovery = load_discovery
        return nil unless discovery[:auth_token]

        @service_client_mutex.synchronize do
          if @service_client.nil? || @service_client_token != discovery[:auth_token]
            @service_client = Client.new(host: DEFAULT_HOST, port: DEFAULT_PORT, auth_token: discovery[:auth_token])
            @service_client_token = discovery[:auth_token]
          end
          @service_client
        end
      end
      private_class_method :service_client

      # Builds the inert fallback payload returned when the feature is disabled
      # or the local service cannot be contacted.
      #
      # @param error [String, nil] optional transport or runtime error detail
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

      # Returns whether the current discovery record points to a responding
      # service.
      #
      # @return [Boolean]
      def self.service_available?
        service_client&.ping || false
      end
      private_class_method :service_available?

      # Returns the on-disk discovery file path shared by local sessions.
      #
      # @return [String]
      def self.discovery_path
        base_dir = defined?(TEMP_DIR) ? TEMP_DIR : Dir.tmpdir
        File.join(base_dir, DISCOVERY_FILENAME)
      end
      private_class_method :discovery_path

      # Loads the current discovery payload, if present.
      #
      # @return [Hash]
      def self.load_discovery
        return {} unless File.exist?(discovery_path)

        JSON.parse(File.read(discovery_path), symbolize_names: true)
      rescue StandardError
        {}
      end
      private_class_method :load_discovery

      # Persists the current service owner metadata so peer sessions can reuse
      # the active service instead of starting a competing owner.
      #
      # @param owner_pid [Integer]
      # @param auth_token [String]
      # @return [void]
      def self.write_discovery(owner_pid:, auth_token:)
        payload = {
          owner_pid: owner_pid,
          auth_token: auth_token,
          updated_at: Time.now.to_i
        }
        temp_path = "#{discovery_path}.#{Process.pid}.tmp"
        File.write(temp_path, JSON.dump(payload))
        File.chmod(0o600, temp_path)
        File.rename(temp_path, discovery_path)
      ensure
        File.delete(temp_path) if defined?(temp_path) && File.exist?(temp_path)
      end
      private_class_method :write_discovery

      # Deletes the discovery file only when the current process still owns it.
      #
      # @return [void]
      def self.delete_discovery_if_owned
        discovery = load_discovery
        return unless discovery[:owner_pid].to_i == Process.pid
        return unless File.exist?(discovery_path)

        File.delete(discovery_path)
      rescue StandardError
        nil
      end
      private_class_method :delete_discovery_if_owned

      # Removes the discovery file when the current process still owns the
      # service and the shared registry is now empty.
      #
      # @return [void]
      def self.cleanup_discovery_if_last_session!
        discovery = load_discovery
        return unless discovery[:owner_pid].to_i == Process.pid

        current_snapshot = snapshot
        return if current_snapshot[:error]
        return unless current_snapshot[:source] == 'ActiveSessionsAPI'
        return unless current_snapshot[:total].to_i.zero?

        stop_service!
      rescue StandardError
        nil
      end
    end
  end
end
