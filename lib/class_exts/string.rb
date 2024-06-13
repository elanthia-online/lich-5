# Lich Carveout
# Extension to String class moved 2024-06-13

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
