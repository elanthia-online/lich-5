# frozen_string_literal: true

# InstanceSettings provides Settings-like access for core Lich functionality
# that runs outside of Script context (e.g., DRParser, command handlers).
#
# Unlike CharSettings and GameSettings which require Script.current.name,
# InstanceSettings uses a fixed script name ('core') that works in any context.
#
# This module supports two scoping modes:
# - Character-scoped: Data specific to current character (game:name)
# - Game-scoped: Data shared across all characters in the game (game only)
#
# Usage:
#   # Character-scoped access (like CharSettings)
#   InstanceSettings['my_key'] = 'value'
#   value = InstanceSettings['my_key']
#
#   # Game-scoped access (for cross-character data like banking)
#   InstanceSettings.game['banking'] = { ... }
#   all_data = InstanceSettings.game['banking']
#
#   # Direct proxy access for complex operations
#   proxy = InstanceSettings.character_proxy
#   proxy['nested']['data'] = 'value'
#
module Lich
  module Common
    module InstanceSettings
      # Script name used for core Lich functionality
      # This allows Settings API to work without Script.current context
      SCRIPT_NAME = 'core'

      # Returns the character-specific scope string (game:name)
      # @return [String] The scope identifier for character-specific data
      def self.character_scope
        "#{XMLData.game}:#{XMLData.name}"
      end

      # Returns the game-wide scope string (game only)
      # @return [String] The scope identifier for game-wide data
      def self.game_scope
        XMLData.game
      end

      # Get a value from character-scoped settings
      # @param name [String, Symbol] The key to retrieve
      # @return [Object] The stored value, or nil if not found
      def self.[](name)
        Settings.get_scoped_setting(character_scope, name, script_name: SCRIPT_NAME)
      end

      # Set a value in character-scoped settings
      # @param name [String, Symbol] The key to set
      # @param value [Object] The value to store
      def self.[]=(name, value)
        Settings.set_script_settings(character_scope, name, value, script_name: SCRIPT_NAME)
      end

      # Returns a root proxy for character-scoped settings
      # Use this for complex nested operations that auto-persist
      # @return [SettingsProxy] A proxy wrapping the character settings root
      def self.character_proxy
        Settings.root_proxy_for(character_scope, script_name: SCRIPT_NAME)
      end

      # Returns a root proxy for game-scoped settings
      # Use this for data shared across all characters (e.g., banking aggregation)
      # @return [SettingsProxy] A proxy wrapping the game settings root
      def self.game_proxy
        Settings.root_proxy_for(game_scope, script_name: SCRIPT_NAME)
      end

      # Convenience accessor for game-scoped data
      # Returns a module that provides [] and []= for game-scoped access
      # @return [Module] A module providing game-scoped access
      def self.game
        @game_accessor ||= Module.new do
          extend self

          def self.[](name)
            InstanceSettings.game_proxy[name]
          end

          def self.[]=(name, value)
            proxy = InstanceSettings.game_proxy
            proxy[name] = value
          end

          def self.to_hash
            Settings.current_script_settings(
              InstanceSettings.game_scope,
              script_name: InstanceSettings::SCRIPT_NAME
            )
          end
        end
      end

      # Returns a hash snapshot of character-scoped settings
      # Note: This returns a copy; modifications won't auto-persist
      # @return [Hash] A copy of the character settings
      def self.to_hash
        Settings.wrap_value_if_container(
          Settings.current_script_settings(character_scope, script_name: SCRIPT_NAME),
          character_scope,
          [],
          script_name: SCRIPT_NAME
        )
      end

      # Deprecated no-op methods for compatibility
      def self.load
        Lich.deprecated('InstanceSettings.load', 'not using, not applicable,', caller[0], fe_log: true)
        nil
      end

      def self.save
        Lich.deprecated('InstanceSettings.save', 'not using, not applicable,', caller[0], fe_log: true)
        nil
      end
    end
  end
end
