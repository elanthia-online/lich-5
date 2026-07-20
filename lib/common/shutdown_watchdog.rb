# frozen_string_literal: true

require_relative 'shutdown_log'

module Lich
  module Common
    # Guarantees that a shutting-down Lich process actually terminates.
    #
    # The teardown sequence runs several steps that can block indefinitely --
    # notably inline +before_dying+/+at_exit+ script hooks, +Vars.save+,
    # +Game.close+ (socket linger), database close, and lifecycle unregister IO.
    # None of them are individually time-bounded. If one hangs, the process
    # never reaches +exit+ and continues to hold its OS resources (open sockets,
    # advisory locks) until it is killed by hand.
    #
    # This watchdog is armed at the start of teardown and disarmed once teardown
    # completes. If the deadline elapses first, it dumps every thread's
    # backtrace (so the debug log records *what* was stuck) and then forces the
    # process to exit, letting the OS reclaim all resources.
    #
    # It is intentionally dependency-light and cross-platform: plain Ruby
    # threads, a condition variable for prompt disarm, and +exit!+.
    module ShutdownWatchdog
      # Default deadline, in seconds, before a stuck shutdown is forced.
      #
      # Chosen to comfortably exceed a healthy teardown (bounded script drain
      # plus state/socket/database closeout) while still bounding a hang.
      #
      # @return [Integer]
      DEFAULT_TIMEOUT_SECONDS = 60

      # Name of the +lich_settings+ row that overrides {DEFAULT_TIMEOUT_SECONDS}.
      #
      # Operator reference:
      # * The value is a whole number of seconds.
      # * A positive value sets the force-exit deadline.
      # * An explicit +0+ or negative value disables the watchdog.
      # * A missing or non-numeric value falls back to {DEFAULT_TIMEOUT_SECONDS};
      #   a malformed value is logged and never silently disables the watchdog.
      #
      # @example Set the deadline to 90 seconds from an in-game console
      #   ;e Lich.db.execute("INSERT OR REPLACE INTO lich_settings(name,value) VALUES('shutdown_watchdog_timeout','90')")
      # @example Disable the watchdog
      #   ;e Lich.db.execute("INSERT OR REPLACE INTO lich_settings(name,value) VALUES('shutdown_watchdog_timeout','0')")
      #
      # @return [String]
      SETTING_NAME = 'shutdown_watchdog_timeout'

      @mutex = Mutex.new
      @condition = ConditionVariable.new
      @armed = false
      @thread = nil

      class << self
        # Arms the watchdog.
        #
        # Spawns a single background thread that waits up to +timeout+ seconds.
        # If the watchdog is still armed when the deadline elapses, it dumps
        # diagnostics and invokes +on_expire+. A subsequent {disarm} wakes the
        # thread immediately and prevents +on_expire+ from running.
        #
        # @param timeout [Numeric] deadline in seconds; +<= 0+ disables (no-op)
        # @param on_expire [#call] action taken when the deadline elapses;
        #   defaults to an immediate, un-trappable process exit
        # @return [Boolean] true when a watchdog thread was started
        def arm(timeout: configured_timeout, on_expire: -> { exit!(1) })
          return false if timeout.to_f <= 0

          @mutex.synchronize do
            return false if @armed

            @armed = true

            # Create the thread and record @thread while still holding the lock
            # so the thread can identify itself. An arm/disarm/arm sequence can
            # leave an earlier thread parked in the wait; gating on
            # @thread == Thread.current ensures only the currently armed
            # watchdog can expire, so a superseded thread never forces an exit.
            @thread = Thread.new do
              expired = @mutex.synchronize do
                current = -> { @armed && @thread == Thread.current }
                @condition.wait(@mutex, timeout) if current.call
                current.call
              end
              if expired
                dump_diagnostics(timeout)
                on_expire.call
              end
            end
          end
          true
        end

        # Disarms the watchdog, waking the waiting thread so it exits without
        # forcing termination. Idempotent and safe to call when not armed.
        #
        # @return [void]
        def disarm
          @mutex.synchronize do
            @armed = false
            @condition.broadcast
          end
          nil
        end

        # Returns whether the watchdog is currently armed.
        #
        # @return [Boolean]
        def armed?
          @mutex.synchronize { @armed }
        end

        # Resolves the configured deadline from +lich_settings+.
        #
        # Falls back to {DEFAULT_TIMEOUT_SECONDS} when the setting is unset,
        # unreadable, or non-numeric. A malformed value is logged and treated as
        # the default rather than being coerced to +0+, so a typo cannot silently
        # disable the watchdog; only an explicit numeric value of +0+ or less
        # disables it.
        #
        # @return [Integer]
        def configured_timeout
          return DEFAULT_TIMEOUT_SECONDS unless defined?(Lich) && Lich.respond_to?(:db) && Lich.db

          raw = Lich.db.get_first_value("SELECT value FROM lich_settings WHERE name='#{SETTING_NAME}';")
          return DEFAULT_TIMEOUT_SECONDS if raw.nil?

          parsed = Integer(raw.to_s.strip, exception: false)
          if parsed.nil?
            log_line("invalid #{SETTING_NAME}=#{raw.inspect}; falling back to #{DEFAULT_TIMEOUT_SECONDS}s")
            return DEFAULT_TIMEOUT_SECONDS
          end
          parsed
        rescue StandardError
          DEFAULT_TIMEOUT_SECONDS
        end

        private

        # Writes a full thread backtrace dump to the shutdown/debug logs so the
        # cause of a hung teardown is captured before the process is forced down.
        #
        # @param timeout [Numeric] the deadline that elapsed, for the log header
        # @return [void]
        def dump_diagnostics(timeout)
          header = "ActiveShutdownWatchdog: shutdown exceeded #{timeout}s -- forcing exit pid=#{Process.pid}"
          log_line(header)
          Thread.list.each do |thread|
            label = thread.name || thread.object_id
            backtrace = (thread.backtrace || ['<no backtrace>']).join("\n\t")
            log_line("thread #{label} status=#{thread.status.inspect}\n\t#{backtrace}")
          end
        rescue StandardError
          nil
        end

        # Emits one diagnostic line to whichever loggers are available.
        #
        # @param message [String]
        # @return [void]
        def log_line(message)
          Lich::Common::ShutdownLog.error(message) if defined?(Lich::Common::ShutdownLog)
          Lich.log("warning: #{message}") if defined?(Lich) && Lich.respond_to?(:log)
        end
      end
    end
  end
end
