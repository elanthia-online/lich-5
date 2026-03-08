# frozen_string_literal: true

require 'time'

module Lich
  module Common
    # Minimal lifecycle coordinator for session summary reporting.
    # Registers a session, emits periodic heartbeats, and unregisters on clean shutdown.
    module SessionLifecycle
      REGISTRATION_DELAY_SECONDS = 15

      @heartbeat_thread = nil
      @running = false
      @started = false
      @mutex = Mutex.new

      def self.resolve_session_name(argv:, account_character: nil)
        if (login_idx = argv.index('--login')) && argv[login_idx + 1]
          argv[login_idx + 1].capitalize
        elsif account_character && !account_character.to_s.empty?
          account_character
        elsif defined?(XMLData) && XMLData.respond_to?(:name) && XMLData.name
          XMLData.name
        else
          "pid-#{Process.pid}"
        end
      end

      def self.resolve_role(argv:, detachable_client_port:)
        return 'headless' if argv.include?('--without-frontend')
        return 'detachable' unless detachable_client_port.nil?

        'session'
      end

      def self.start(session_name:, role:, heartbeat_interval: SessionsSettings::HEARTBEAT_INTERVAL_SECONDS, registration_delay: REGISTRATION_DELAY_SECONDS)
        @mutex.synchronize do
          return false if @started

          started_epoch = Time.now.to_i
          started_iso = Time.at(started_epoch).utc.iso8601
          scheduled_register_epoch = started_epoch + registration_delay.to_i
          scheduled_register_iso = Time.at(scheduled_register_epoch).utc.iso8601

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
            break unless @running

            begin
              Lich.log(
                "info: SessionLifecycle deferred register attempt " \
                "pid=#{Process.pid} session=#{session_name.inspect} role=#{role.inspect} " \
                "attempt_epoch=#{Time.now.to_i}"
              ) if Lich.respond_to?(:log)
              SessionsSettings.register_session(
                pid: Process.pid,
                session_name: session_name,
                role: role,
                state: 'running'
              )
              Lich.log(
                "info: SessionLifecycle deferred register success " \
                "pid=#{Process.pid} session=#{session_name.inspect} role=#{role.inspect} " \
                "success_epoch=#{Time.now.to_i}"
              ) if Lich.respond_to?(:log)
            rescue StandardError => e
              Lich.log(
                "warning: SessionLifecycle deferred register failed: #{e.class}: #{e.message} " \
                "pid=#{Process.pid} session=#{session_name.inspect} role=#{role.inspect} " \
                "started_epoch=#{started_epoch} started_iso=#{started_iso} delay=#{registration_delay}s"
              ) if Lich.respond_to?(:log)
            end

            loop do
              sleep heartbeat_interval
              break unless @running

              Lich.log(
                "debug: SessionLifecycle heartbeat tick " \
                "pid=#{Process.pid} session=#{session_name.inspect} role=#{role.inspect} " \
                "tick_epoch=#{Time.now.to_i}"
              ) if Lich.respond_to?(:log)
              SessionsSettings.heartbeat(pid: Process.pid, state: 'running')
            end
          rescue StandardError => e
            Lich.log("warning: SessionLifecycle heartbeat failed: #{e.class}: #{e.message}") if Lich.respond_to?(:log)
          end
        end
        true
      rescue StandardError => e
        Lich.log("warning: SessionLifecycle start failed: #{e.class}: #{e.message}") if Lich.respond_to?(:log)
        false
      end

      def self.stop
        @mutex.synchronize do
          return false unless @started

          @running = false
          @heartbeat_thread&.kill
          @heartbeat_thread = nil
          SessionsSettings.unregister_session(pid: Process.pid)
          @started = false
        end
        true
      rescue StandardError => e
        Lich.log("warning: SessionLifecycle stop failed: #{e.class}: #{e.message}") if Lich.respond_to?(:log)
        false
      end
    end
  end
end
