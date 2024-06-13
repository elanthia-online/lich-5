# Lich Carveout
# Extension to NilClass moved 2024-06-13

class NilClass
  def dup
    nil
  end

  def method_missing(*_args)
    nil
  end

  def split(*_val)
    Array.new
  end

  def to_s
    ""
  end

  def strip
    ""
  end

  def +(val)
    val
  end

  def closed?
    true
  end
end
