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

      # Number of times a discovered owner is probed before it is treated as
      # unreachable during an election decision.
      #
      # A single probe can time out transiently while the host is saturated by
      # bulk session churn (mass login/logout), even against a perfectly healthy
      # owner. Re-probing before electing a replacement prevents a disruptive,
      # unnecessary takeover.
      #
      # @return [Integer]
      OWNER_PROBE_ATTEMPTS = 3

      # Delay, in seconds, between owner responsiveness probes.
      #
      # @return [Float]
      OWNER_PROBE_BACKOFF_SECONDS = 0.1

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

        ensure_service_internal!(allow_bootstrap: true)
      end

      # Returns whether an already-admitted call path can reach a healthy
      # service without re-reading the feature flag on every hot-path call.
      #
      # This helper preserves the operational kill switch by requiring the
      # real feature flag before bootstrapping a *new* owner while still
      # allowing healthy existing owners to be reused by admitted callers.
      #
      # @param allow_bootstrap [Boolean] when false, never start a new server
      # @return [Boolean]
      def self.ensure_service_internal!(allow_bootstrap:)
        # This process already owns a healthy server: keep the shared discovery
        # pointer authoritative and reuse it. This self-heals a pointer that was
        # cleared or overwritten by a peer, without a disruptive re-election.
        return true if serving_owner_reasserted?

        # A healthy peer owner is already reachable on the fast path.
        return true if service_available?
        return false unless allow_bootstrap

        # Re-check the live kill switch on the bootstrap path so admitted
        # callers can reuse an existing owner without re-reading the flag,
        # while still preventing creation of a brand-new owner after disable.
        return false unless enabled?

        # A single probe can time out transiently under heavy churn. Re-probe
        # with a short backoff before electing ourselves so we do not take over
        # from a briefly-overloaded but healthy owner. Performed outside the
        # bootstrap lock so it never stalls peer threads in this process.
        return true if service_responsive?

        @mutex.synchronize do
          # Another thread or process may have won election while we waited for
          # the lock.
          return true if service_available?

          release_in_process_zombie!
          bootstrap_owner!
        end
      rescue StandardError => e
        Lich.log("warning: ActiveSessions service unavailable: #{e.class}: #{e.message}") if Lich.respond_to?(:log)
        false
      end
      private_class_method :ensure_service_internal!

      # Ensures the shared discovery pointer advertises this process whenever it
      # owns a running server, rewriting the pointer only when it is missing or
      # stale.
      #
      # Because only one process can hold the service port at a time, a running
      # in-process server is proof that this process is the true owner; any
      # discovery record naming a different owner is therefore stale. Re-writing
      # it here lets an owner recover a pointer that a peer deleted or clobbered
      # after a transient false positive, within a single heartbeat, instead of
      # the pointer staying lost until this process exits.
      #
      # @return [Boolean] true when this process owns a healthy server
      def self.serving_owner_reasserted?
        @mutex.synchronize do
          return false unless owns_running_server?

          reassert_discovery_unlocked!
          true
        end
      end
      private_class_method :serving_owner_reasserted?

      # Returns whether this process holds a server with a live accept loop.
      #
      # @return [Boolean]
      def self.owns_running_server?
        !@server.nil? && @server.running?
      end
      private_class_method :owns_running_server?

      # Rewrites the discovery pointer to this process when it is absent or does
      # not already match this owner's pid and token.
      #
      # @note The caller must hold {@mutex}.
      # @return [void]
      def self.reassert_discovery_unlocked!
        discovery = load_discovery
        return if discovery[:owner_pid] == Process.pid && discovery[:auth_token] == @server.auth_token

        write_discovery(owner_pid: Process.pid, auth_token: @server.auth_token)
      end
      private_class_method :reassert_discovery_unlocked!

      # Probes the discovered service repeatedly with a short backoff so a
      # transient timeout under load does not read as an unreachable owner.
      #
      # @param attempts [Integer] number of probe attempts
      # @param backoff [Float] delay in seconds between attempts
      # @return [Boolean] true when any probe succeeds
      def self.service_responsive?(attempts: OWNER_PROBE_ATTEMPTS, backoff: OWNER_PROBE_BACKOFF_SECONDS)
        attempts.times do |attempt|
          return true if service_available?

          sleep(backoff) unless attempt == attempts - 1
        end
        false
      end
      private_class_method :service_responsive?

      # Stops and clears an in-process server whose accept loop has died, so its
      # still-bound socket is released before a fresh bind is attempted.
      #
      # @note The caller must hold {@mutex}.
      # @return [void]
      def self.release_in_process_zombie!
        return unless @server && !@server.running?

        Lich.log("warning: ActiveSessions in-process zombie detected pid=#{Process.pid} -- releasing socket") if Lich.respond_to?(:log)
        @server.stop
        @server = nil
      end
      private_class_method :release_in_process_zombie!

      # Binds a fresh owner server for this process and publishes discovery.
      #
      # The bind itself is the authority on whether another owner still holds
      # the port, which avoids trusting the bare liveness of a possibly-recycled
      # pid:
      #
      # * A successful bind means no live owner held the port (it exited, or its
      #   pid was recycled by an unrelated process), so we become the owner and
      #   overwrite any stale discovery pointer.
      # * A failed bind means a real owner still holds the port, so we leave its
      #   discovery pointer untouched and back off until a later tick. We never
      #   delete a peer's pointer, so a healthy owner is never knocked offline by
      #   a transient probe failure.
      #
      # @note The caller must hold {@mutex}.
      # @return [Boolean] true when this process became the owner
      def self.bootstrap_owner!
        @registry ||= Registry.new
        @server ||= Server.new(
          host: DEFAULT_HOST,
          port: DEFAULT_PORT,
          registry: @registry,
          auth_token: SecureRandom.hex(32)
        )

        unless @server.start
          @server = nil
          return false
        end

        write_discovery(owner_pid: Process.pid, auth_token: @server.auth_token)
        true
      end
      private_class_method :bootstrap_owner!

      # Registers or updates a session record in the local service.
      #
      # @param payload [Hash] normalized session metadata
      # @return [Boolean] true when the service accepted the update
      def self.register_session(payload)
        return false unless enabled?
        return false unless ensure_service!

        service_client&.upsert(payload)&.fetch(:ok, false) || false
      end

      # Registers or updates a session record from a lifecycle path that
      # already admitted the feature gate at startup.
      #
      # When the current service owner has exited, this allows a surviving
      # session to bootstrap a replacement owner so session visibility is
      # maintained. The kill-switch is still enforced: ensure_service_internal!
      # re-checks enabled? before creating a new owner.
      #
      # @param payload [Hash] normalized session metadata
      # @return [Boolean] true when the service accepted the update
      def self.register_session_admitted(payload)
        return false unless ensure_service_internal!(allow_bootstrap: true)

        service_client&.upsert(payload)&.fetch(:ok, false) || false
      end
      private_class_method :register_session_admitted

      # Removes a session record by pid.
      #
      # @param pid [Integer]
      # @return [Boolean] true when the service accepted the removal request
      def self.unregister_session(pid:)
        return false unless enabled?
        return false unless ensure_service!

        service_client&.remove(pid)&.fetch(:ok, false) || false
      end

      # Removes a session record from a lifecycle path that already admitted
      # the feature gate at startup.
      #
      # @param pid [Integer]
      # @return [Boolean] true when the service accepted the removal request
      def self.unregister_session_admitted(pid:)
        return false unless ensure_service_internal!(allow_bootstrap: false)

        service_client&.remove(pid)&.fetch(:ok, false) || false
      end
      private_class_method :unregister_session_admitted

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

      # Queries the currently discovered active-sessions service without
      # consulting the local feature flag state or attempting to bootstrap a
      # new owner.
      #
      # This is intended for read-only operator tools and CLI queries that may
      # run outside a normal Lich session process. If no service is already
      # available, the result is a normalized fallback payload.
      #
      # @return [Hash] a normalized snapshot or an inert fallback payload
      def self.query_snapshot
        response = service_client&.snapshot
        return fallback_snapshot(error: 'active sessions service unavailable') unless response
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
        File.open(temp_path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
          file.write(JSON.dump(payload))
        end
        File.rename(temp_path, discovery_path)
      ensure
        File.delete(temp_path) if defined?(temp_path) && File.exist?(temp_path)
      end
      private_class_method :write_discovery

      # Deletes the discovery file only when the current process still owns it.
      #
      # @return [void]
      def self.delete_discovery_if_owned
        delete_discovery_if_owner(Process.pid)
      end
      private_class_method :delete_discovery_if_owned

      # Deletes the discovery file only when it still belongs to the given owner.
      #
      # Re-reads the file before deletion to avoid a race where another process
      # has written a fresh discovery between the caller's initial read and this
      # deletion attempt.
      #
      # @param expected_owner_pid [Integer]
      # @param expected_auth_token [String, nil] when provided, also requires
      #   the token to match so a fresh rewrite by the same PID is not deleted
      # @return [void]
      def self.delete_discovery_if_owner(expected_owner_pid, expected_auth_token = nil)
        current = load_discovery
        return unless current[:owner_pid].to_i == expected_owner_pid.to_i
        return if expected_auth_token && current[:auth_token] != expected_auth_token

        File.delete(discovery_path) if File.exist?(discovery_path)
      rescue StandardError
        nil
      end
      private_class_method :delete_discovery_if_owner

      # Removes the discovery file when the current process still owns the
      # service and the shared registry is now empty.
      #
      # @return [void]
      def self.cleanup_discovery_if_last_session!
        discovery = load_discovery
        return unless discovery[:owner_pid].to_i == Process.pid

        current_snapshot = query_snapshot
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
