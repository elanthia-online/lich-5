# frozen_string_literal: true

module Lich
  module InternalAPI
    module ActiveSessions
      # Process-local lifecycle coordinator for active sessions registration.
      module Lifecycle
        HEARTBEAT_INTERVAL_SECONDS = 90

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
        # @return [Boolean]
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
            thread = Thread.new do
              loop do
                sleep heartbeat_interval
                break unless @running

                upsert_current_session
              end
            rescue StandardError => e
              Lich.log("warning: ActiveSessions heartbeat failed: #{e.class}: #{e.message}") if Lich.respond_to?(:log)
            end
            @heartbeat_thread = thread
          end

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
        # @return [Boolean]
        def self.stop
          return false unless ActiveSessions.enabled?

          thread = nil
          @mutex.synchronize do
            return false unless @started

            @running = false
            thread = @heartbeat_thread
            @heartbeat_thread = nil
          end

          thread&.join(0.5)
          thread&.kill if thread&.alive?
          ActiveSessions.unregister_session(pid: Process.pid)

          @mutex.synchronize do
            @started = false
            @session_name = nil
            @role = nil
            @listener_host = nil
            @listener_port = nil
            @listener_connected = false
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
        # @return [void]
        def self.clear_listener
          return unless ActiveSessions.enabled?

          @mutex.synchronize do
            @listener_host = nil
            @listener_port = nil
            @listener_connected = false
          end
          upsert_current_session if @started
        end

        # Returns the current process session payload.
        #
        # @return [Hash]
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
          return unless @started

          ActiveSessions.register_session(current_payload)
        end
        private_class_method :upsert_current_session

        def self.resolve_frontend
          return $frontend if defined?($frontend) && !$frontend.nil? && !$frontend.to_s.empty?

          nil
        end
        private_class_method :resolve_frontend

        def self.resolve_game_code
          return XMLData.game if defined?(XMLData) && XMLData.respond_to?(:game) && !XMLData.game.to_s.empty?

          nil
        end
        private_class_method :resolve_game_code
      end
    end
  end
end
