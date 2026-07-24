# frozen_string_literal: true

require_relative 'frontend_launcher'

module Lich
  module Common
    # Launches Saga through Saga's account/character auto-login intent. Saga
    # remains responsible for authentication and for starting its Via-Lich
    # child, so this path never creates or abandons a Lich-side game key.
    module SagaManagedLauncher
      class << self
        # Launches one Saga-managed Via-Lich session.
        #
        # Invalid identifiers raise immediately. Expected machine-local
        # failures (Saga unavailable or process spawn failure) return a
        # structured failure for the GUI to report.
        #
        # @param account [String] Saga account with a saved password
        # @param character [String] character to launch
        # @param game_code [String] Saga instance code
        # @param plan_builder [#saga_managed_login_plan] injectable plan API
        # @param process_launcher [#call] callable accepting environment and argv
        # @return [Hash] +{ ok: true, pid: Integer }+ or
        #   +{ ok: false, error: String }+
        # @raise [ArgumentError] for invalid caller input
        def launch(
          account:,
          character:,
          game_code:,
          plan_builder: FrontendLauncher,
          process_launcher: method(:spawn_detached)
        )
          plan = plan_builder.saga_managed_login_plan(
            account: account,
            character: character,
            game_code: game_code
          )
          pid = process_launcher.call(plan.environment, plan.argv)
          { ok: true, pid: pid }
        rescue FrontendLauncher::Error, SystemCallError => e
          { ok: false, error: e.message }
        end

        private

        def spawn_detached(environment, argv)
          pid = spawn(environment, *argv)
          Process.detach(pid)
          pid
        end
      end
    end
  end
end
