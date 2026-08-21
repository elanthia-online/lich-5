# frozen_string_literal: true

require_relative 'authentication/cli'
require_relative 'front-end'
require_relative 'saga_launch_policy'
require_relative 'saga_managed_launcher'

module Lich
  module Common
    # Routes saved CLI/TUI login intent to Saga when Saga owns authentication.
    #
    # Headless and character-generator requests remain on Lich's existing
    # authentication path. Saga and Custom Launch are incompatible ownership
    # requests and fail before authentication.
    module SagaManagedLogin
      Decision = Struct.new(:action, :target, :error, keyword_init: true) do
        def initialize(action:, target: nil, error: nil)
          super(action: action, target: target, error: error)
          freeze
        end
      end

      class << self
        # Decides whether a saved CLI login should launch through Saga.
        #
        # @param character [String] requested saved character
        # @param game_code [String, Symbol, nil] requested game instance
        # @param frontend [String, Symbol, nil] requested frontend
        # @param custom_launch [String, Symbol, nil] requested Custom Launch
        # @param headless [Boolean] whether Lich should run without a frontend
        # @param data_dir [String, nil] directory containing saved entries
        # @param target_resolver [#resolve_saved_target] injectable saved-target API
        # @return [Decision] +:launch+, +:passthrough+, or +:error+
        # @raise [ArgumentError] when a candidate character name is blank
        def cli_decision(
          character:,
          game_code:,
          frontend:,
          custom_launch:,
          headless:,
          data_dir: nil,
          target_resolver: Authentication::CLI
        )
          if SagaLaunchPolicy.custom_launch_conflict?(frontend: frontend, custom_launch: custom_launch)
            return decision(:error, error: SagaLaunchPolicy::CUSTOM_LAUNCH_CONFLICT)
          end

          return decision(:passthrough) if headless
          return decision(:passthrough) if custom_launch?(custom_launch)
          return decision(:passthrough) if character.to_s.match?(Authentication::LoginHelpers::NEW_CHARACTER_LOGIN)
          return decision(:passthrough) unless frontend == :__unset || saga?(frontend)

          target = target_resolver.resolve_saved_target(
            character,
            game_code: game_code,
            frontend: frontend,
            custom_launch: custom_launch,
            data_dir: data_dir
          )

          if target.nil?
            return decision(:error, error: "No saved Saga entry matched #{character}") if saga?(frontend)

            return decision(:passthrough)
          end

          if SagaLaunchPolicy.custom_launch_conflict?(frontend: target[:frontend], custom_launch: target[:custom_launch])
            return decision(:error, error: SagaLaunchPolicy::CUSTOM_LAUNCH_CONFLICT)
          end

          return decision(:passthrough) if custom_launch?(target[:custom_launch])
          return decision(:passthrough) unless saga?(target[:frontend])

          decision(:launch, target: target)
        end

        # Launches a prepared Saga target.
        #
        # @param target [Hash] account, character, and game_code identifiers
        # @param launcher [#launch] injectable Saga managed-launch API
        # @return [Hash] launcher result
        # @raise [ArgumentError] when target is not a Hash
        def launch(target, launcher: SagaManagedLauncher)
          raise ArgumentError, 'Saga launch target must be a Hash' unless target.is_a?(Hash)

          launcher.launch(
            account: target[:account],
            character: target[:character],
            game_code: target[:game_code]
          )
        end

        private

        def saga?(frontend)
          Frontend.canonical_name(frontend) == 'saga'
        end

        def custom_launch?(value)
          value != :__unset && !value.to_s.strip.empty?
        end

        def decision(action, target: nil, error: nil)
          Decision.new(action: action, target: target, error: error)
        end
      end
    end
  end
end
