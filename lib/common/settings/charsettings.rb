# Carve out from Lich5 for module CharSettings
# 2024-06-13

module Lich
  module Common
    module CharSettings
      # CHAR_SCOPE_PREFIX = XMLData.game # Not strictly needed if active_scope is always dynamic

      def self.active_scope
        # Ensure XMLData.game and XMLData.name are available and up-to-date when scope is needed
        "#{XMLData.game}:#{XMLData.name}"
      end

      def self.[](name)
        Settings.get_scoped_setting(active_scope, name)
      end

      def self.[]=(name, value)
        Settings.set_script_settings(active_scope, name, value)
      end

      def self.to_hash
        # NB:  This method does not behave like a standard Ruby hash request.
        # It returns a root proxy for the character settings scope, allowing persistent
        # modifications on the returned object for legacy support.
        Settings.wrap_value_if_container(Settings.current_script_settings(active_scope), active_scope, [])
      end

      # deprecated
      def CharSettings.load
        Lich.deprecated("CharSettings.load", "not using, not applicable,", caller[0], fe_log: true)
        nil
      end

      def CharSettings.save
        Lich.deprecated("CharSettings.save", "not using, not applicable,", caller[0], fe_log: true)
        nil
      end

      def CharSettings.save_all
        Lich.deprecated("CharSettings.save_all", "not using, not applicable,", caller[0], fe_log: true)
        nil
      end

      def CharSettings.clear
        Lich.deprecated("CharSettings.clear", "not using, not applicable,", caller[0], fe_log: true)
        nil
      end

      def CharSettings.auto=(_val)
        Lich.deprecated("CharSettings.auto=(val)", "not using, not applicable,", caller[0], fe_log: true)
      end

      def CharSettings.auto
        Lich.deprecated("CharSettings.auto", "not using, not applicable,", caller[0], fe_log: true)
        nil
      end

      def CharSettings.autoload
        Lich.deprecated("CharSettings.autoload", "not using, not applicable,", caller[0], fe_log: true)
        nil
      end
    end
  end
end
