# frozen_string_literal: true

module Lich
  module Common
    module Authentication
      # Normalizes the launch-result hash returned by a single-character
      # authentication (EAccess's non-legacy .auth, WebLogin's .auth) to one
      # shared shape, so Authenticator and downstream consumers (LaunchData,
      # session_launcher) don't need to know which provider produced it.
      #
      # Deliberately a plain Hash, not a Struct/value class -- callers
      # (LaunchData.prepare) already consume it duck-typed as
      # `auth_data.map { |k, v| ... }`, and EAccess's legacy multi-game
      # enumeration mode returns a wholly different shape (an Array of
      # per-character hashes) that this module does not apply to.
      module LaunchResult
        # KEY is the one field both providers always have: EAccess gets it
        # from every successful L response (even the generator path, which
        # can omit GAMEHOST/GAMEPORT -- see eaccess_spec.rb's generator
        # tests), and WebLogin gets it from the final redirect's query
        # string. GAMEHOST/GAMEPORT are correspondingly NOT required here.
        REQUIRED_KEYS = %w[key].freeze

        # Raised when a provider's launch data is missing a field every
        # consumer of this shared shape depends on.
        class MissingLaunchDataError < StandardError
          def initialize(missing_keys)
            super("launch result missing required key(s): #{missing_keys.join(', ')}")
          end
        end

        # @param raw [Hash] provider-specific launch data (string or symbol keys)
        # @return [Hash] the same data with lowercase string keys, frozen
        # @raise [MissingLaunchDataError] if a required key is absent or blank
        def self.normalize(raw)
          normalized = raw.each_with_object({}) { |(k, v), h| h[k.to_s.downcase] = v }

          missing = REQUIRED_KEYS.select { |key| normalized[key].to_s.empty? }
          raise MissingLaunchDataError, missing unless missing.empty?

          normalized.freeze
        end
      end
    end
  end
end
