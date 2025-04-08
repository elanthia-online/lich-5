# Carve out from Lich 5 for module GameSettings
# 2024-06-13

module Lich
  module Common
    module GameSettings
      private

      def self.deprecated_method_call(method_name)
        Lich.deprecated("GameSettings.", method_name, 'not using, not applicable,', caller[0], fe_log: true)
        nil
      end

      def GameSettings.[](name)
        Settings.to_hash(XMLData.game)[name]
      end

      def GameSettings.[]=(name, value)
        Settings.set_script_settings("#{XMLData.game}:", name, value)
      end

      def GameSettings.to_hash
        Settings.to_hash(XMLData.game)
      end

      # deprecated
      def GameSettings.load
        deprecated_method_call('load')
        nil
      end

      def GameSettings.save
        deprecated_method_call('save')
        nil
      end

      def GameSettings.save_all
        deprecated_method_call('save_all')
        nil
      end

      def GameSettings.clear
        deprecated_method_call('clear')
        nil
      end

      def GameSettings.auto=(_val)
        deprecated_method_call('auto=(val)')
        return nil
      end

      def GameSettings.auto
        deprecated_method_call('auto')
        nil
      end

      def GameSettings.autoload
        deprecated_method_call('autoload')
        nil
      end
    end
  end
end
