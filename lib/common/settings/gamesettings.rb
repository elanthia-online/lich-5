# Carve out from Lich 5 for module GameSettings
# 2024-06-13

module Lich
  module Common
    module GameSettings
      def GameSettings.[](name)
        Settings.to_hash(XMLData.game)[name]
      end

      def GameSettings.[]=(name, value)
        Settings.set_script_settings("#{XMLData.game}:", name, value)
      end

      def GameSettings.to_hash
        Settings.to_hash(XMLData.game)
      end
    end
  end
end
