# Carve out from Lich 5 for module GameSettings
# 2024-06-13

module Lich
  module Common
    module GameSettings
      def GameSettings.[](name)
        Settings.[](XMLData.game, name)
      end

      def GameSettings.[]=(name, value)
        Settings.set_script_settings(XMLData.game, name, value)
      end

      def GameSettings.to_hash
        Settings.to_hash(XMLData.game)
      end

      # deprecated
      def GameSettings.load
        Lich.deprecated('GameSettings.load', 'not using, not applicable,', caller[0], fe_log: true)
        nil
      end

      def GameSettings.save
        Lich.deprecated('GameSettings.save', 'not using, not applicable,', caller[0], fe_log: true)
        nil
      end

      def GameSettings.save_all
        Lich.deprecated('GameSettings.save_all', 'not using, not applicable,', caller[0], fe_log: true)
        nil
      end

      def GameSettings.clear
        Lich.deprecated('GameSettings.clear', 'not using, not applicable,', caller[0], fe_log: true)
        nil
      end

      def GameSettings.auto=(_val)
        Lich.deprecated('GameSettings.auto=(val)', 'not using, not applicable,', caller[0], fe_log: true)
        return nil
      end

      def GameSettings.auto
        Lich.deprecated('GameSettings.auto', 'not using, not applicable,', caller[0], fe_log: true)
        nil
      end

      def GameSettings.autoload
        Lich.deprecated('GameSettings.autoload', 'not using, not applicable,', caller[0], fe_log: true)
        nil
      end
    end
  end
end
