# Carve out for module CharSettings
# 2024-06-13

module CharSettings
  def CharSettings.[](name)
    Settings.to_hash("#{XMLData.game}:#{XMLData.name}")[name]
  end

  def CharSettings.[]=(name, value)
    Settings.to_hash("#{XMLData.game}:#{XMLData.name}")[name] = value
  end

  def CharSettings.to_hash
    Settings.to_hash("#{XMLData.game}:#{XMLData.name}")
  end

  ## deprecating these methods - temporary
  def CharSettings.load; Lich.deprecated('CharSettings.load', 'not using, not applicable,', caller[0]); end
  
  def CharSettings.save; Lich.deprecated('CharSettings.save', 'not using, not applicable,', caller[0]); end
  
  def CharSettings.save_all; Lich.deprecated('CharSettings.save_all', 'not using, not applicable,', caller[0]); end
  
  def CharSettings.clear; Lich.deprecated('CharSettings.clear', 'not using, not applicable,', caller[0]); end
  
  def CharSettings.auto=(val); Lich.deprecated('CharSettings.auto=(val)', 'not using, not applicable,', caller[0]); end
  
  def CharSettings.auto; Lich.deprecated('CharSettings.auto', 'not using, not applicable,', caller[0]); end

  def CharSettings.autoload; Lich.deprecated('CharSettings.autoload', 'not using, not applicable,', caller[0]); end
end
