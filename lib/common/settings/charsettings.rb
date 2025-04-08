# Carve out from Lich5 for module CharSettings
# 2024-06-13

module Lich
  module Common
    module CharSettings
      private

      def self.deprecated_method_call(method_name)
        Lich.deprecated("CharSettings.", method_name, 'not using, not applicable,', caller[0], fe_log: true)
        nil
      end

      def CharSettings.[](name)
        Settings.to_hash("#{XMLData.game}:#{XMLData.name}")[name]
      end

      def CharSettings.[]=(name, value)
        Settings.set_script_settings("#{XMLData.game}:#{XMLData.name}", name, value)
      end

      def CharSettings.to_hash
        Settings.to_hash("#{XMLData.game}:#{XMLData.name}")
      end

      # deprecated
      def CharSettings.load
        deprecated_method_call('load')
        nil
      end

      def CharSettings.save
        deprecated_method_call('save')
        nil
      end

      def CharSettings.save_all
        deprecated_method_call('save_all')
        nil
      end

      def CharSettings.clear
        deprecated_method_call('clear')
        nil
      end

      def CharSettings.auto=(_val)
        deprecated_method_call('auto=(val)')
        return nil
      end

      def CharSettings.auto
        deprecated_method_call('auto')
        nil
      end

      def CharSettings.autoload
        deprecated_method_call('autoload')
        nil
      end
    end
  end
end
