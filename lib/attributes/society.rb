# carveout for infomon rewrite

class Society
  def self.status
    Infomon.get("society.status")
  end

  def self.rank
    Infomon.get("society.rank")
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

  def self.favor
    Infomon.get('resources.voln_favor')
  end

  def self.serialize
    [self.status, self.rank]
  end
end
