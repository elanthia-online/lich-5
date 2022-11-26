class NilClass
  def dup
    nil
  end

  def method_missing(*args)
    nil
  end

  def split(*val)
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
