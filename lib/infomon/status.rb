# API for char Status
# todo: should include jaws / condemn / others?

require "ostruct"

module Status
  def self.bound?
    Infomon.get("status.bound")
  end

  def self.calmed?
    Infomon.get("status.calmed")
  end

  def self.cutthroat?
    Infomon.get("status.cutthroat")
  end

  def self.hiddenNPC?
    Infomon.get("status.hiddenNPC")
  end

  def self.revealedNPC?
    Infomon.get("status.revealedNPC")
  end

  def self.silenced?
    Infomon.get("status.silenced")
  end

  def self.sleeping?
    Infomon.get("status.sleeping")
  end

  # todo: does this serve a purpose?
  def self.serialize
    [self.bound?, self.calmed?, self.cutthroat?,
     self.hiddenNPC?, self.revealedNPC?,
     self.silenced?, self.sleeping?]
  end
end
