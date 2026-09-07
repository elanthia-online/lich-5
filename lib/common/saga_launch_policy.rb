# frozen_string_literal: true

require_relative 'front-end'

module Lich
  module Common
    # Defines launch-ownership combinations accepted by Saga entry points.
    module SagaLaunchPolicy
      CUSTOM_LAUNCH_CONFLICT = '--saga and --custom-launch cannot be used together; Saga launches must use the Saga-managed launch contract.'

      class << self
        # Returns whether a request combines Saga-managed and Custom Launch
        # ownership models.
        #
        # @param frontend [String, Symbol, nil]
        # @param custom_launch [String, Symbol, nil]
        # @return [Boolean]
        def custom_launch_conflict?(frontend:, custom_launch:)
          Frontend.canonical_name(frontend) == 'saga' && custom_launch?(custom_launch)
        end

        private

        def custom_launch?(value)
          value != :__unset && !value.to_s.strip.empty?
        end
      end
    end
  end
end
