# frozen_string_literal: true

require_relative 'shutdown_log'

module Lich
  module Common
    # Performs local cleanup after the frontend or game connection is disrupted.
    #
    # Unlike {OrderlyShutdown}, this runner does not assume game request/response
    # I/O is still usable. It preserves local state and runs bounded script
    # teardown as best effort, then lets the existing post-join closeout handle
    # sockets, databases, lifecycle unregister, and process exit.
    module BestEffortShutdownCleanup
      # Result for one best-effort cleanup attempt.
      Result = Struct.new(
        :completed,
        :failures,
        :script_shutdown_result,
        :scripts_drained,
        :vars_saved,
        keyword_init: true
      ) do
        # @return [Boolean] whether all local cleanup steps completed
        def completed?
          completed
        end

        # @return [Boolean] whether any local cleanup step raised
        def failed?
          !failures.empty?
        end

        # @return [Boolean] whether script shutdown ran and left no registered scripts
        def scripts_drained?
          scripts_drained
        end

        # @return [Boolean] whether local script settings were saved
        def vars_saved?
          vars_saved
        end
      end

      class << self
        # Executes best-effort local cleanup once.
        #
        # This path is intended for connection disruption after critical game I/O
        # has already stopped or become unreliable. It avoids closing the game
        # socket itself and does not describe script hooks as graceful.
        #
        # @param coordinator [ShutdownCoordinator] state/intent coordinator
        # @param initial_scripts [Array<#kill,#name>] scripts present at cleanup start
        # @param remaining_scripts [#call] returns scripts still registered
        # @param script_drain [#run] script drain service
        # @param vars [#save] local script settings persistence
        # @param active_sessions_lifecycle [#update_connected, nil] optional session registry
        # @param slow_threshold [Float] seconds before script drain reports slow scripts
        # @return [Result] stored best-effort cleanup result
        # @raise [ArgumentError] when caller input is invalid
        def run(coordinator:, initial_scripts:, remaining_scripts:, script_drain:, vars:, active_sessions_lifecycle: nil, slow_threshold: 1.5)
          validate!(coordinator: coordinator, remaining_scripts: remaining_scripts, script_drain: script_drain, vars: vars)

          result = Result.new(
            completed: false,
            failures: [],
            scripts_drained: false,
            vars_saved: false
          )

          stored_result = coordinator.begin_best_effort_cleanup(result)
          return stored_result unless stored_result.equal?(result)

          log_info("best-effort shutdown cleanup starting reason=#{coordinator.reason || :unknown}")
          update_active_sessions(result, active_sessions_lifecycle)
          drain_scripts(result, initial_scripts, remaining_scripts, script_drain, slow_threshold)
          save_vars(result, vars)
          finish(result)
        end

        private

        def validate!(coordinator:, remaining_scripts:, script_drain:, vars:)
          raise ArgumentError, "coordinator must respond to #begin_best_effort_cleanup" unless coordinator.respond_to?(:begin_best_effort_cleanup)
          raise ArgumentError, "coordinator must respond to #reason" unless coordinator.respond_to?(:reason)
          raise ArgumentError, "remaining_scripts must respond to #call" unless remaining_scripts.respond_to?(:call)
          raise ArgumentError, "script_drain must respond to #run" unless script_drain.respond_to?(:run)
          raise ArgumentError, "vars must respond to #save" unless vars.respond_to?(:save)
        end

        def update_active_sessions(result, active_sessions_lifecycle)
          run_step(result, "ActiveSessions connection update") do
            if active_sessions_lifecycle && active_sessions_lifecycle.respond_to?(:update_connected)
              active_sessions_lifecycle.update_connected(false)
            end
          end
        end

        def drain_scripts(result, initial_scripts, remaining_scripts, script_drain, slow_threshold)
          run_step(result, "script shutdown") do
            log_info("stopping scripts during best-effort shutdown cleanup...")
            result.script_shutdown_result = script_drain.run(
              initial_scripts: initial_scripts,
              remaining_scripts: remaining_scripts,
              slow_threshold: slow_threshold
            )
            result.scripts_drained = script_drain_complete?(result.script_shutdown_result)
            log_script_drain_result(result.script_shutdown_result)
          end
        end

        def save_vars(result, vars)
          run_step(result, "Vars.save") do
            log_info("saving script settings during best-effort shutdown cleanup...")
            vars.save
            result.vars_saved = true
          end
        end

        def finish(result)
          result.completed = !result.failed? && result.scripts_drained? && result.vars_saved?
          log_info("best-effort shutdown cleanup #{result.completed? ? 'finished' : 'finished with warnings'}")
          result
        end

        def run_step(result, description)
          yield
        rescue StandardError => e
          result.failures << "#{description}: #{e.class}: #{e.message}"
          log_warning("#{description} failed during best-effort shutdown cleanup: #{e.class}: #{e.message}")
        end

        def script_drain_complete?(script_shutdown_result)
          return true unless script_shutdown_result.respond_to?(:scripts_remaining)

          script_shutdown_result.scripts_remaining.to_i.zero?
        end

        def log_script_drain_result(script_shutdown_result)
          return unless script_shutdown_result

          slow_scripts = script_shutdown_result.respond_to?(:slow_scripts) ? script_shutdown_result.slow_scripts : []
          scripts_remaining = script_shutdown_result.respond_to?(:scripts_remaining) ? script_shutdown_result.scripts_remaining.to_i : 0
          return if slow_scripts.empty? && scripts_remaining.zero?

          details = script_shutdown_result.respond_to?(:details) ? script_shutdown_result.details : script_shutdown_result.inspect
          if scripts_remaining.positive?
            log_warning("best-effort shutdown cleanup script drain #{details}")
          else
            log_info("best-effort shutdown cleanup script drain #{details}")
          end
        end

        def log_info(message)
          ShutdownLog.info(message)
        end

        def log_warning(message)
          ShutdownLog.warning(message)
        end
      end
    end
  end
end
