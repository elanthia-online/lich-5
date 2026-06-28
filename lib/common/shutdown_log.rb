# frozen_string_literal: true

module Lich
  module Common
    # Centralizes shutdown-specific log formatting and diagnostic gating.
    #
    # Default shutdown logs should answer "why did Lich exit?" without requiring
    # debug mode. Diagnostic logs are reserved for timing/backtrace detail that
    # is useful during investigation but too noisy for routine shutdowns.
    module ShutdownLog
      @mutex = Mutex.new
      @user_exit_summary_active = false
      @user_exit_summary_disqualified = false
      @buffered_info = []

      class << self
        # @param message [String] human-readable shutdown event
        # @return [void]
        def info(message)
          return if buffer_info(message)

          write(:info, message)
        end

        # @param message [String] human-readable shutdown warning
        # @return [void]
        def warning(message)
          flush_disqualified_user_exit_summary!
          write(:warning, message)
        end

        # @param message [String] human-readable shutdown error
        # @return [void]
        def error(message)
          flush_disqualified_user_exit_summary!
          write(:error, message)
        end

        # Logs diagnostic shutdown detail only when diagnostics are enabled.
        #
        # @param message [String] investigation detail
        # @return [void]
        def debug(message)
          write(:debug, message) if diagnostics_enabled?
        end

        # @return [Boolean] whether shutdown diagnostics should be verbose
        def diagnostics_enabled?
          defined?(ARGV) && ARGV.include?('--debug')
        end

        # Starts buffering routine info logs for a possible clean user exit.
        #
        # Warnings and errors still emit immediately and disqualify the compact
        # summary, allowing the caller to flush buffered info lines later.
        #
        # @return [void]
        def begin_user_exit_summary!
          mutex.synchronize do
            @user_exit_summary_active = true
            @user_exit_summary_disqualified = false
            @buffered_info = []
          end
        end

        # Emits a clean user-exit summary or flushes buffered info logs.
        #
        # @param message [String] compact clean-exit summary
        # @return [Boolean] whether the compact summary was emitted
        def complete_user_exit_summary(message)
          buffered_info = nil
          should_summarize = false

          mutex.synchronize do
            if @user_exit_summary_active && !@user_exit_summary_disqualified
              should_summarize = true
            else
              buffered_info = @buffered_info.dup
            end
            reset_user_exit_summary_state
          end

          if should_summarize
            write(:info, message)
            true
          else
            buffered_info&.each { |buffered_message| write(:info, buffered_message) }
            false
          end
        end

        # Flushes any buffered info logs and disables user-exit summarization.
        #
        # @return [void]
        def flush_user_exit_summary!
          buffered_info = nil
          mutex.synchronize do
            buffered_info = @buffered_info.dup
            reset_user_exit_summary_state
          end
          buffered_info.each { |buffered_message| write(:info, buffered_message) }
        end

        private

        def mutex
          @mutex
        end

        def buffer_info(message)
          mutex.synchronize do
            if @user_exit_summary_active
              @buffered_info << message
              true
            else
              false
            end
          end
        end

        def flush_disqualified_user_exit_summary!
          buffered_info = nil
          mutex.synchronize do
            if @user_exit_summary_active
              @user_exit_summary_disqualified = true
              buffered_info = @buffered_info.dup
              reset_user_exit_summary_state
            else
              buffered_info = []
            end
          end
          buffered_info.each { |buffered_message| write(:info, buffered_message) }
        end

        def reset_user_exit_summary_state
          @user_exit_summary_active = false
          @user_exit_summary_disqualified = false
          @buffered_info = []
        end

        # Writes a formatted shutdown log line when Lich logging is available.
        #
        # @param level [Symbol] shutdown log severity
        # @param message [String] human-readable shutdown message
        # @return [void]
        def write(level, message)
          return unless defined?(Lich) && Lich.respond_to?(:log)

          Lich.log("#{level}: #{message}")
        end
      end
    end
  end
end
