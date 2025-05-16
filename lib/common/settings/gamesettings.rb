# Carve out from Lich 5 for module GameSettings
# 2024-06-13

module Lich
  module Common
    module GameSettings
      # Helper to get the active scope for GameSettings
      # Assumes XMLData.game is available and provides the correct scope string.
      def self.active_scope
        XMLData.game
      end

      def self.[](name)
        Settings.get_scoped_setting(active_scope, name)
      end

      def self.[]=(name, value)
        Settings.set_script_settings(active_scope, name, value)
      end

      def self.to_hash
        # NB:  This method does not behave like a standard Ruby hash request.
        # It returns a root proxy for the game settings scope, allowing persistent
        # modifications on the returned object for legacy support.
        Settings.wrap_value_if_container(Settings.current_script_settings(active_scope), active_scope, [])
      end

      # deprecated
      def GameSettings.load
        Lich.deprecated("GameSettings.load", "not using, not applicable,", caller[0], fe_log: true)
        nil
      end

      def GameSettings.save
        Lich.deprecated("GameSettings.save", "not using, not applicable,", caller[0], fe_log: true)
        nil
      end

      def GameSettings.save_all
        Lich.deprecated("GameSettings.save_all", "not using, not applicable,", caller[0], fe_log: true)
        nil
      end

      def GameSettings.clear
        Lich.deprecated("GameSettings.clear", "not using, not applicable,", caller[0], fe_log: true)
        nil
      end

      def GameSettings.auto=(_val)
        Lich.deprecated("GameSettings.auto=(val)", "not using, not applicable,", caller[0], fe_log: true)
      end

      def GameSettings.auto
        Lich.deprecated("GameSettings.auto", "not using, not applicable,", caller[0], fe_log: true)
        nil
      end

      def GameSettings.autoload
        Lich.deprecated("GameSettings.autoload", "not using, not applicable,", caller[0], fe_log: true)
        nil
      end
    end
  end
end
