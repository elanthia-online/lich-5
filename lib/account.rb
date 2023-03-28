module Account
  @@name ||= nil
  @@type ||= nil
  @@game ||= nil

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
end
