module Account
  @@name ||= nil
  @@type ||= nil
  @@game ||= nil
  @@members ||= []

  def self.name
    @@name
  end

  def self.name=(value)
    @@name = value
  end

  def self.type
    @@type
  end

  def self.type=(value)
    if value =~ /(NORMAL|PREMIUM|TRIAL|INTERNAL|FREE)/
      @@type = Regexp.last_match(1)
    end
  end

  def self.game
    @@game
  end

  def self.game=(value)
    @@game = value
  end

  def self.members
    @@members
  end

  def self.members=(value)
    potential_members = []
    for code_name in value.sub(/^C\t[0-9]+\t[0-9]+\t[0-9]+\t[0-9]+[\t\n]/, '').scan(/[^\t]+\t[^\t^\n]+/)
      _char_code, char_name = code_name.split("\t")
      potential_members.push(char_name)
    end
    @@members = potential_members
  end
end
