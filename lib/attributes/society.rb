# carveout for infomon rewrite

class Society
  def self.status
    Infomon.get("society.status").to_s
  end

  def self.rank
    Infomon.get("society.rank").to_i
  end

  def self.step
    self.rank
  end

  def self.member
    self.status.dup
  end

  def self.task
    XMLData.society_task
  end

  def self.serialize
    [self.status, self.rank]
  end
end
