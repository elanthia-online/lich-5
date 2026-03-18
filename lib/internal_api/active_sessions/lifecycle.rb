# frozen_string_literal: true

module Lich
  module InternalAPI
    module ActiveSessions
      # Process-local lifecycle coordinator for active sessions registration.
      #
      # This module adapts Lich runtime state into active-sessions payloads. It
      # intentionally keeps only a small amount of mutable process-local state:
      # identifying metadata, detachable listener details, and a heartbeat
      # thread handle.
      module Lifecycle
        # Default heartbeat cadence for refreshing the current process entry and
        # detecting service-owner failover quickly enough for multi-session use.
        #
        # @return [Integer]
        HEARTBEAT_INTERVAL_SECONDS = 5

        @heartbeat_thread = nil
        @running = false
        @started = false
        @listener_host = nil
        @listener_port = nil
        @listener_connected = false
        @session_name = nil
        @role = nil
        @started_at = nil
        @mutex = Mutex.new

        # Resolves the reporting session name from runtime context.
        #
        # @param argv [Array<String>]
        # @param account_character [String, nil]
        # @return [String]
        def self.resolve_session_name(argv:, account_character: nil)
          if (login_idx = argv.index('--login')) && argv[login_idx + 1]
            argv[login_idx + 1].capitalize
          elsif account_character && !account_character.to_s.empty?
            account_character
          elsif defined?(XMLData) && XMLData.respond_to?(:name) && !XMLData.name.to_s.empty?
            XMLData.name
          else
            "pid-#{Process.pid}"
          end
        end

        # Resolves the logical runtime role for active sessions reporting.
        #
        # @param argv [Array<String>]
        # @param detachable_client_port [Integer, nil]
        # @return [String]
        def self.resolve_role(argv:, detachable_client_port:)
          return 'headless' if argv.include?('--without-frontend')
          return 'detachable' unless detachable_client_port.nil?

          'session'
        end

        # Starts lifecycle registration and periodic heartbeats.
        #
        # @param session_name [String]
        # @param role [String]
        # @param heartbeat_interval [Integer]
        # @return [Boolean] true when lifecycle tracking started
        def self.start(session_name:, role:, heartbeat_interval: HEARTBEAT_INTERVAL_SECONDS)
          return false unless ActiveSessions.enabled?

          thread = nil
          @mutex.synchronize do
            return false if @started

            @session_name = session_name
            @role = role
            @started_at = Time.now.to_i
            @running = true
            @started = true
          end

          thread = Thread.new do
            loop do
              sleep heartbeat_interval
              break unless running?

              upsert_current_session
            end
          rescue StandardError => e
            Lich.log("warning: ActiveSessions heartbeat failed: #{e.class}: #{e.message}") if Lich.respond_to?(:log)
          end

          @mutex.synchronize { @heartbeat_thread = thread if @started }

          upsert_current_session
          true
        rescue StandardError => e
          @mutex.synchronize do
            @running = false
            @started = false
            @heartbeat_thread = nil
            @session_name = nil
            @role = nil
            @listener_host = nil
            @listener_port = nil
            @listener_connected = false
            @started_at = nil
          end
          thread.kill if thread.respond_to?(:alive?) && thread.alive?
          Lich.log("warning: ActiveSessions lifecycle start failed: #{e.class}: #{e.message}") if Lich.respond_to?(:log)
          false
        end

        # Stops lifecycle registration and removes the current process session.
        #
        # @return [Boolean] true when a running lifecycle was stopped
        def self.stop
          return false unless ActiveSessions.enabled?

          thread = nil
          @mutex.synchronize do
            return false unless @started

            @running = false
            @started = false
            thread = @heartbeat_thread
            @heartbeat_thread = nil
          end

          thread&.join(0.5)
          thread&.kill if thread&.alive?
          ActiveSessions.unregister_session(pid: Process.pid)
          ActiveSessions.cleanup_discovery_if_last_session!

          @mutex.synchronize do
            @session_name = nil
            @role = nil
            @listener_host = nil
            @listener_port = nil
            @listener_connected = false
            @started_at = nil
          end
          true
        rescue StandardError => e
          Lich.log("warning: ActiveSessions lifecycle stop failed: #{e.class}: #{e.message}") if Lich.respond_to?(:log)
          false
        end

        # Updates detachable listener metadata for the current session.
        #
        # @param host [String]
        # @param port [Integer]
        # @param connected [Boolean]
        # @return [void]
        def self.update_listener(host:, port:, connected:)
          return unless ActiveSessions.enabled?

          @mutex.synchronize do
            @listener_host = host
            @listener_port = port
            @listener_connected = connected
          end
          upsert_current_session
        end

        # Clears detachable listener metadata for the current session.
        #
        # This is used when detachable listener infrastructure is torn down and
        # the public snapshot should stop reporting a listener endpoint.
        #
        # @return [void]
        def self.clear_listener
          return unless ActiveSessions.enabled?

          started = false
          @mutex.synchronize do
            @listener_host = nil
            @listener_port = nil
            @listener_connected = false
            started = @started
          end
          upsert_current_session if started
        end

        # Returns the current process session payload.
        #
        # @return [Hash] normalized payload suitable for registry upsert
        def self.current_payload
          @mutex.synchronize do
            {
              pid: Process.pid,
              session_name: @session_name,
              role: @role,
              frontend: resolve_frontend,
              game_code: resolve_game_code,
              started_at: @started_at,
              connected: @listener_port.nil? ? true : @listener_connected,
              listener_host: @listener_host,
              listener_port: @listener_port,
              hidden: false
            }
          end
        end

        # Pushes the current process state into the active sessions service.
        #
        # @return [void]
        def self.upsert_current_session
          payload = nil
          @mutex.synchronize do
            return unless @started

            payload = {
              pid: Process.pid,
              session_name: @session_name,
              role: @role,
              frontend: resolve_frontend,
              game_code: resolve_game_code,
              started_at: @started_at,
              connected: @listener_port.nil? ? true : @listener_connected,
              listener_host: @listener_host,
              listener_port: @listener_port,
              hidden: false
            }
          end

          ActiveSessions.register_session(payload)
        end
        private_class_method :upsert_current_session

        # Returns whether the heartbeat loop should continue running.
        #
        # @return [Boolean]
        def self.running?
          @mutex.synchronize { @running }
        end
        private_class_method :running?

        # Resolves the current frontend identifier from runtime globals.
        #
        # @return [String, nil]
        def self.resolve_frontend
          return $frontend if defined?($frontend) && !$frontend.nil? && !$frontend.to_s.empty?

          nil
        end
        private_class_method :resolve_frontend

        # Resolves the current game code from XMLData when available.
        #
        # @return [String, nil]
        def self.resolve_game_code
          return XMLData.game if defined?(XMLData) && XMLData.respond_to?(:game) && !XMLData.game.to_s.empty?

          nil
        end
        private_class_method :resolve_game_code
      end
    end
  end
end
