# Carve out for module GameSettings
# 2024-06-13

module GameSettings
  def GameSettings.[](name)
    Settings.to_hash(XMLData.game)[name]
  end

  def GameSettings.[]=(name, value)
    Settings.to_hash(XMLData.game)[name] = value
  end

  def GameSettings.to_hash
    Settings.to_hash(XMLData.game)
  end

  ## deprecating these methods - temporary
  def GameSettings.load; Lich.deprecated('GameSettings.load', 'not using, not applicable,', caller[0]); end

  def GameSettings.save; Lich.deprecated('GameSettings.save', 'not using, not applicable,', caller[0]); end

  def GameSettings.save_all; Lich.deprecated('GameSettings.save_all', 'not using, not applicable,', caller[0]); end

  def GameSettings.clear; Lich.deprecated('GameSettings.clear', 'not using, not applicable,', caller[0]); end

  def GameSettings.auto=(_val); Lich.deprecated('GameSettings.auto=(val)', 'not using, not applicable,', caller[0]); end

  def GameSettings.auto; Lich.deprecated('GameSettings.auto', 'not using, not applicable,', caller[0]); end

  def GameSettings.autoload; Lich.deprecated('GameSettings.autoload', 'not using, not applicable,', caller[0]); end
end
