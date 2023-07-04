# API for char Status
# todo: should include jaws / condemn / others?

require "ostruct"

module Status
  def self.bound?
    Infomon.get_bool("status.bound") && Effects::Debuffs.to_h.has_key?('Bind')
  end

  def self.calmed?
    Infomon.get_bool("status.calmed") && Effects::Debuffs.to_h.has_key?('Calm')
  end

  def self.cutthroat?
    Infomon.get_bool("status.cutthroat") && Effects::Debuffs.to_h.has_key?('Major Bleed')
  end

  def self.silenced?
    Infomon.get_bool("status.silenced") && Effects::Debuffs.to_h.has_key?('Silenced')
  end

  def self.sleeping?
    Infomon.get_bool("status.sleeping") && Effects::Debuffs.to_h.has_key?('Sleep')
  end

  # deprecate these in global_defs after warning, consider bringing other status maps over
  def self.webbed?
    XMLData.indicator['IconWEBBED'] == 'y'
  end

  def self.dead?
    XMLData.indicator['IconDEAD'] == 'y'
  end

  def self.stunned?
    XMLData.indicator['IconSTUNNED'] == 'y'
  end

  def self.muckled?
    return Status.webbed? || Status.dead? || Status.stunned? || Status.bound? || Status.sleeping?
  end

  # todo: does this serve a purpose?
  def self.serialize
    [self.bound?, self.calmed?, self.cutthroat?, self.silenced?, self.sleeping?]
  end
end
