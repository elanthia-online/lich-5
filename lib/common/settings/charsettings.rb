# Carve out from Lich5 for module CharSettings
# 2024-06-13

module Lich
  module Common
    module CharSettings
      def CharSettings.[](name)
        Settings.to_hash("#{XMLData.game}:#{XMLData.name}")[name]
      end

      def CharSettings.[]=(name, value)
        Settings.set_script_settings("#{XMLData.game}:#{XMLData.name}", name, value)
      end

      def CharSettings.to_hash
        Settings.to_hash("#{XMLData.game}:#{XMLData.name}")
      end
    end
  end
end
