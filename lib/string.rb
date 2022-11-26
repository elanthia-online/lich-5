class String
  @@elevated_untaint = proc { |what| what.orig_untaint }
  alias :orig_untaint :untaint
  def untaint
    @@elevated_untaint.call(self)
  end

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
