# Carve out from lich.rbw
# extension to Numeric class 2024-06-13

class Numeric
  def as_time
    sprintf("%d:%02d:%02d", (self / 60).truncate, self.truncate % 60, ((self % 1) * 60).truncate)
  end

  def with_commas
    self.to_s.reverse.scan(/(?:\d*\.)?\d{1,3}-?/).join(',').reverse
  end

  def seconds
    return self
  end
  alias :second :seconds

  def minutes
    return self * 60
  end
  alias :minute :minutes

  def hours
    return self * 3600
  end
  alias :hour :hours

  def days
    return self * 86400
  end
  alias :day :days
end
