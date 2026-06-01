# frozen_string_literal: true

module Lich
  module Common
    # Centralizes shutdown-specific log formatting and diagnostic gating.
    #
    # Default shutdown logs should answer "why did Lich exit?" without requiring
    # debug mode. Diagnostic logs are reserved for timing/backtrace detail that
    # is useful during investigation but too noisy for routine shutdowns.
    module ShutdownLog
      class << self
        # @param message [String] human-readable shutdown event
        # @return [void]
        def info(message)
          write(:info, message)
        end

        # @param message [String] human-readable shutdown warning
        # @return [void]
        def warning(message)
          write(:warning, message)
        end

        # @param message [String] human-readable shutdown error
        # @return [void]
        def error(message)
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

        private

        def write(level, message)
          return unless defined?(Lich) && Lich.respond_to?(:log)

          Lich.log("#{level}: #{message}")
        end
      end
    end
  end
end
