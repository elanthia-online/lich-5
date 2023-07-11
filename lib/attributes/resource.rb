module Resource
  def self.weekly
    Infomon.get('resource.weekly')
  end

  def self.total
    Infomon.get('resource.total')
  end

  def self.suffused
    Infomon.get('resource.suffused')
  end

  def self.check(quiet = false)
    Lich::Util.issue_command('resource', /^Health: \d+\/\d+\s+Mana: \d+\/\d+\s+Stamina: \d+\/\d+\s+Spirit: \d+\/\d+/, /<prompt/, true, 5, true, true, quiet)
    return [self.weekly, self.total, self.suffused]
end
