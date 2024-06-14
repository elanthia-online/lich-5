# Carve out from lich.rbw
# extension to String class

class String
  def to_s
    self.dup
  end

  def stream
    @stream
  end

  def stream=(val)
    @stream ||= val
  end
end
