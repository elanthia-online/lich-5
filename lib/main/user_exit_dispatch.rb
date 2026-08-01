# frozen_string_literal: true

require_relative '../common/shutdown_intent'
require_relative '../common/shutdown_coordinator'
require_relative '../common/orderly_shutdown'
require_relative '../common/shutdown_watchdog'

module Lich
  module Main
    # User-initiated ("...exit"/"...quit") shutdown entry point shared by the
    # primary and detachable frontend client loops in +lib/main/main.rb+.
    #
    # Extracted from main.rb so the ordering guarantee it enforces is directly
    # testable: the shutdown watchdog must be armed *before*
    # {Lich::Common::OrderlyShutdown.request_user_exit} runs, because that call
    # drains scripts and runs their +before_dying+/+at_exit+ hooks inline, any of
    # which can hang. A bare +request_user_exit+ would run that hang-prone drain
    # unprotected.
    #
    # @since 5.19.2
    module UserExitDispatch
      module_function

      # Arms the shutdown watchdog (idempotent) and then runs the orderly
      # user-exit sequence. Extra keyword options are forwarded to
      # {Lich::Common::OrderlyShutdown.request_user_exit} (used by tests to inject
      # the script drain, +Vars+, and +Game+ collaborators).
      #
      # @param source [Symbol] shutdown source recorded in the coordinator/logs
      # @param request_options [Hash] forwarded to +request_user_exit+
      # @return [Object] the orderly-shutdown result
      def run_orderly_user_shutdown(source: :primary_frontend, **request_options)
        Lich::Common::ShutdownWatchdog.arm if defined?(Lich::Common::ShutdownWatchdog)
        Lich::Common::OrderlyShutdown.request_user_exit(
          source: source,
          active_sessions_lifecycle: active_sessions_lifecycle,
          **request_options
        )
      end

      # Detachable-frontend dispatch for one raw client line.
      #
      # Applies the same +$cmd_prefix+ prefixing the client loops use before
      # matching, and when the (prefixed) line is a user-exit command, arms the
      # watchdog and runs the orderly shutdown under the +:detachable_frontend+
      # source. The caller breaks its read loop when this returns true.
      #
      # @param client_string [String] raw line received from the detachable client
      # @param cmd_prefix [String] frontend command prefix (default +$cmd_prefix+)
      # @param request_options [Hash] forwarded to {run_orderly_user_shutdown}
      # @return [Boolean] true when the line was an exit command and was handled
      def dispatch_detachable_client(client_string, cmd_prefix: $cmd_prefix, **request_options)
        prefixed = "#{cmd_prefix}#{client_string}"
        return false unless Lich::Common::ShutdownIntent.user_exit_command?(prefixed)

        run_orderly_user_shutdown(source: :detachable_frontend, **request_options)
        true
      end

      # Resolves the ActiveSessions lifecycle when the feature is loaded, so a
      # normal exit updates the session registry; nil otherwise.
      #
      # @return [Object, nil]
      def active_sessions_lifecycle
        Lich::InternalAPI::ActiveSessions::Lifecycle if defined?(Lich::InternalAPI::ActiveSessions::Lifecycle)
      end
    end
  end
end
