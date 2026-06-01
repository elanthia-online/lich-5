# frozen_string_literal: true

require_relative 'shutdown_log'

module Lich
  module Common
    # Runs the explicit user-requested shutdown sequence while game I/O is alive.
    #
    # This runner is separate from {ShutdownCoordinator}: the coordinator records
    # intent and progress, while this module performs teardown steps and updates
    # the stored result. Connection-loss cleanup can add its own runner without
    # overloading the state object.
    module OrderlyShutdown
      # Result for one orderly-shutdown attempt.
      Result = Struct.new(
        :completed,
        :failures,
        :script_shutdown_result,
        :scripts_drained,
        :vars_saved,
        :game_closed,
        keyword_init: true
      ) do
        # @return [Boolean] whether every required orderly-shutdown step completed
        def completed?
          completed
        end

        # @return [Boolean] whether any step raised or script drain was incomplete
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

        # @return [Boolean] whether the game connection close step ran
        def game_closed?
          game_closed
        end
      end

      class << self
        # Executes orderly user shutdown once.
        #
        # The sequence intentionally runs script hooks and local state save before
        # closing the game connection. If another frontend thread already started
        # the same sequence, this method returns that existing result.
        #
        # @param coordinator [ShutdownCoordinator] state/intent coordinator
        # @param initial_scripts [Array<#kill,#name>] scripts present at shutdown start
        # @param remaining_scripts [#call] returns scripts still registered
        # @param script_drain [#run] script drain service
        # @param vars [#save] local script settings persistence
        # @param game [#close] game connection facade
        # @param active_sessions_lifecycle [#update_connected, nil] optional session registry
        # @param slow_threshold [Float] seconds before script drain reports slow scripts
        # @return [Result] stored orderly-shutdown result
        # @raise [ArgumentError] when caller input is invalid or reason is not :user_exit
        def run(coordinator:, initial_scripts:, remaining_scripts:, script_drain:, vars:, game:, active_sessions_lifecycle: nil, slow_threshold: 1.5)
          validate!(coordinator: coordinator, remaining_scripts: remaining_scripts, script_drain: script_drain, vars: vars, game: game)
          raise ArgumentError, "orderly user exit requires reason=:user_exit" unless coordinator.orderly_user_exit?

          result = Result.new(
            completed: false,
            failures: [],
            scripts_drained: false,
            vars_saved: false,
            game_closed: false
          )

          stored_result = coordinator.begin_orderly_shutdown(result)
          return stored_result unless stored_result.equal?(result)

          log_info("orderly user shutdown starting")
          update_active_sessions(result, active_sessions_lifecycle)
          drain_scripts(result, initial_scripts, remaining_scripts, script_drain, slow_threshold)
          save_vars(result, vars)
          close_game(result, game)
          finish(result)
        end

        private

        def validate!(coordinator:, remaining_scripts:, script_drain:, vars:, game:)
          raise ArgumentError, "coordinator must respond to #orderly_user_exit?" unless coordinator.respond_to?(:orderly_user_exit?)
          raise ArgumentError, "coordinator must respond to #begin_orderly_shutdown" unless coordinator.respond_to?(:begin_orderly_shutdown)
          raise ArgumentError, "remaining_scripts must respond to #call" unless remaining_scripts.respond_to?(:call)
          raise ArgumentError, "script_drain must respond to #run" unless script_drain.respond_to?(:run)
          raise ArgumentError, "vars must respond to #save" unless vars.respond_to?(:save)
          raise ArgumentError, "game must respond to #close" unless game.respond_to?(:close)
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
            log_info("stopping scripts before closing game connection...")
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
            log_info("saving script settings before closing game connection...")
            vars.save
            result.vars_saved = true
          end
        end

        def close_game(result, game)
          run_step(result, "Game.close") do
            log_info("closing game connection after orderly user shutdown...")
            game.close
            result.game_closed = true
          end
        end

        def finish(result)
          result.completed = !result.failed? && result.scripts_drained? && result.vars_saved? && result.game_closed?
          log_info("orderly user shutdown #{result.completed? ? 'finished' : 'finished with warnings'}")
          result
        end

        def run_step(result, description)
          yield
        rescue StandardError => e
          result.failures << "#{description}: #{e.class}: #{e.message}"
          log_warning("#{description} failed during orderly user shutdown: #{e.class}: #{e.message}")
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
            log_warning("orderly user shutdown script drain #{details}")
          else
            log_info("orderly user shutdown script drain #{details}")
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
