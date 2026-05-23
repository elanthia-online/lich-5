# frozen_string_literal: true

require 'time'

module Lich
  module Common
    # Minimal lifecycle coordinator for session summary reporting.
    # Registers a session, emits periodic heartbeats, and unregisters on clean shutdown.
    module SessionLifecycle
      REGISTRATION_DELAY_SECONDS = 5

      @heartbeat_thread = nil
      @running = false
      @started = false
      @feature_enabled = false
      @mutex = Mutex.new

      # Resolves the reporting session name from launch/runtime context.
      #
      # Resolution order:
      # 1) `--login <name>` CLI argument
      # 2) account character provided by auth layer
      # 3) `XMLData.name` when available after parser initialization
      # 4) deterministic PID fallback (`pid-<pid>`)
      #
      # @param argv [Array<String>] process argument vector
      # @param account_character [String, nil] resolved account character name
      # @return [String] normalized session identifier used in session summary state
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

      # Resolves the logical runtime role used for reporting.
      #
      # @param argv [Array<String>] process argument vector
      # @param detachable_client_port [Integer, nil] configured detachable client port
      # @return [String] one of `headless`, `detachable`, or `session`
      def self.resolve_role(argv:, detachable_client_port:)
        return 'detachable' unless detachable_client_port.nil?
        return 'headless' if argv.include?('--without-frontend')

        'session'
      end

      # Starts lifecycle tracking and heartbeat emission for the current process.
      # Registration is intentionally deferred to allow XMLData game context to initialize.
      #
      # @param session_name [String] resolved session identifier
      # @param role [String] runtime role (`session`, `detachable`, `headless`)
      # @param heartbeat_interval [Integer] heartbeat interval in seconds
      # @param registration_delay [Integer] initial registration delay in seconds
      # @return [Boolean] true when started, false when already started or failed
      def self.start(session_name:, role:, heartbeat_interval: SessionsSettings::HEARTBEAT_INTERVAL_SECONDS, registration_delay: REGISTRATION_DELAY_SECONDS)
        feature_enabled = SessionsSettings.enabled?
        return false unless feature_enabled

        @mutex.synchronize do
          return false if @started

          @feature_enabled = feature_enabled
          frontend = resolve_frontend
          started_epoch = Time.now.to_i
          started_iso = Time.at(started_epoch).utc.iso8601
          scheduled_register_epoch = started_epoch + registration_delay.to_i
          scheduled_register_iso = Time.at(scheduled_register_epoch).utc.iso8601
          registration_complete = false

          begin
            @running = true
            @started = true
            Lich.log(
              "info: SessionLifecycle start scheduled " \
              "pid=#{Process.pid} session=#{session_name.inspect} role=#{role.inspect} " \
              "started_epoch=#{started_epoch} started_iso=#{started_iso} " \
              "register_at_epoch=#{scheduled_register_epoch} register_at_iso=#{scheduled_register_iso} " \
              "heartbeat_interval=#{heartbeat_interval}s"
            ) if Lich.respond_to?(:log)

            @heartbeat_thread = Thread.new do
              sleep registration_delay
              Thread.exit unless @running

              if game_context_ready?
                registration_complete = attempt_register(
                  session_name: session_name,
                  role: role,
                  frontend: frontend,
                  started_epoch: started_epoch,
                  started_iso: started_iso,
                  registration_delay: registration_delay
                )
              else
                Lich.log(
                  "info: SessionLifecycle deferred register postponed " \
                  "pid=#{Process.pid} session=#{session_name.inspect} role=#{role.inspect} " \
                  "reason=xmldata_game_unavailable attempt_epoch=#{Time.now.to_i}"
                ) if Lich.respond_to?(:log)
              end

              loop do
                sleep heartbeat_interval
                break unless @running

                game_code = resolve_game_code
                if !registration_complete && !game_code.nil?
                  registration_complete = attempt_register(
                    session_name: session_name,
                    role: role,
                    frontend: frontend,
                    started_epoch: started_epoch,
                    started_iso: started_iso,
                    registration_delay: registration_delay
                  )
                end

                Lich.log(
                  "debug: SessionLifecycle heartbeat tick " \
                  "pid=#{Process.pid} session=#{session_name.inspect} role=#{role.inspect} " \
                  "tick_epoch=#{Time.now.to_i}"
                ) if Lich.respond_to?(:log)
                SessionsSettings.send(:heartbeat_admitted,
                                      pid: Process.pid,
                                      state: 'running',
                                      session_name: session_name,
                                      role: role,
                                      frontend: frontend,
                                      game_code: game_code)
              end
            rescue StandardError => e
              Lich.log("warning: SessionLifecycle heartbeat failed: #{e.class}: #{e.message}") if Lich.respond_to?(:log)
            end
          rescue StandardError
            @running = false
            @started = false
            @feature_enabled = false
            @heartbeat_thread = nil
            raise
          end
        end
        true
      rescue StandardError => e
        Lich.log("warning: SessionLifecycle start failed: #{e.class}: #{e.message}") if Lich.respond_to?(:log)
        false
      end

      # Stops lifecycle tracking and unregisters the current process.
      #
      # @return [Boolean] true when stop/unregister succeeded, false when not running or failed
      def self.stop
        heartbeat_thread = nil
        was_enabled = false
        @mutex.synchronize do
          return false unless @started

          was_enabled = @feature_enabled
          @running = false
          heartbeat_thread = @heartbeat_thread
          @heartbeat_thread = nil
        end

        # Cooperative shutdown first: allow the heartbeat loop to observe
        # @running=false and exit naturally before using hard-kill fallback.
        heartbeat_thread&.join(0.5)
        heartbeat_thread&.kill if heartbeat_thread&.alive?

        @mutex.synchronize do
          @heartbeat_thread = nil
          SessionsSettings.send(:unregister_session_admitted, pid: Process.pid) if was_enabled
          @started = false
          @feature_enabled = false
        end
        true
      rescue StandardError => e
        Lich.log("warning: SessionLifecycle stop failed: #{e.class}: #{e.message}") if Lich.respond_to?(:log)
        false
      end

      # Resolves frontend identifier for session reporting.
      #
      # @return [String, nil] resolved frontend value or nil when unavailable
      def self.resolve_frontend
        return $frontend if defined?($frontend) && !$frontend.nil? && !$frontend.to_s.empty?

        nil
      end

      # Resolves game code from XML runtime state.
      #
      # @return [String, nil] game code when XML context is ready
      def self.resolve_game_code
        return XMLData.game if defined?(XMLData) && XMLData.respond_to?(:game) && !XMLData.game.to_s.empty?

        nil
      end

      # Indicates whether XML runtime context is sufficient for registration.
      #
      # @return [Boolean]
      def self.game_context_ready?
        !resolve_game_code.nil?
      end

      # Returns whether the current lifecycle was admitted while the feature
      # flag was enabled. Stop uses this latched state instead of re-reading
      # the backing feature flag, which may require a database query.
      #
      # @return [Boolean]
      def self.feature_enabled?
        @mutex.synchronize { @feature_enabled }
      end
      private_class_method :feature_enabled?

      # Performs deferred register attempt once game context is available.
      #
      # @param session_name [String]
      # @param role [String]
      # @param frontend [String, nil]
      # @param started_epoch [Integer]
      # @param started_iso [String]
      # @param registration_delay [Integer]
      # @return [Boolean] true when register call succeeds, false otherwise
      def self.attempt_register(session_name:, role:, frontend:, started_epoch:, started_iso:, registration_delay:)
        begin
          game_code = resolve_game_code
          return false if game_code.nil?

          Lich.log(
            "info: SessionLifecycle deferred register attempt " \
            "pid=#{Process.pid} session=#{session_name.inspect} role=#{role.inspect} " \
            "attempt_epoch=#{Time.now.to_i}"
          ) if Lich.respond_to?(:log)
          SessionsSettings.send(:register_session_admitted,
                                pid: Process.pid,
                                session_name: session_name,
                                role: role,
                                state: 'running',
                                frontend: frontend,
                                game_code: game_code)
          Lich.log(
            "info: SessionLifecycle deferred register success " \
            "pid=#{Process.pid} session=#{session_name.inspect} role=#{role.inspect} " \
            "success_epoch=#{Time.now.to_i}"
          ) if Lich.respond_to?(:log)
          true
        rescue StandardError => e
          Lich.log(
            "warning: SessionLifecycle deferred register failed: #{e.class}: #{e.message} " \
            "pid=#{Process.pid} session=#{session_name.inspect} role=#{role.inspect} " \
            "started_epoch=#{started_epoch} started_iso=#{started_iso} delay=#{registration_delay}s"
          ) if Lich.respond_to?(:log)
          false
        end
      end
    end
  end
end
