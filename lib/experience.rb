require "ostruct"

module Experience
  def self.fame
    Infomon.get("experience.fame")
  end

  def self.fxp_current
    Infomon.get("experience.fxp_current")
  end

  def self.fxp_max
    Infomon.get("experience.fxp_max")
  end

  def self.exp
    Stats.exp
  end

  def self.axp
    Infomon.get("experience.ascension_experience")
  end

  def self.txp
    Infomon.get("experience.total_experience")
  end

  def self.lte
    Infomon.get("experience.long_term_experience")
  end

  def self.deeds
    Infomon.get("experience.deeds")
  end

  def self.serialize
    [self.fame, self.fxp_current, self.fxp_max,
     self.exp, self.axp, self.txp,
     self.lte, self.deeds]
  end
end
