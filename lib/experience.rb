require "ostruct"

module Experience
  def self.fame
    Infomon.get("experience.fame")
  end

  def self.fxp_current
    Infomon.get("experience.field_experience_current")
  end

  def self.fxp_max
    Infomon.get("experience.field_experience_max")
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

  def self.percent_fxp
    (fxp_current.to_f / fxp_max.to_f) * 100
  end

  def self.percent_axp
    (axp.to_f / txp.to_f) * 100
  end

  def self.percent_exp
    (exp.to_f / txp.to_f) * 100
  end

  def self.lte
    Infomon.get("experience.long_term_experience")
  end

  def self.deeds
    Infomon.get("experience.deeds")
  end

  def self.deaths_sting
    Infomon.get("experience.deaths_sting")
  end
end
