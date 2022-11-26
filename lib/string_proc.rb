class StringProc
  def initialize(string)
    @string = string
    @string.untaint
  end

  def kind_of?(type)
    Proc.new {}.kind_of? type
  end

  def class
    Proc
  end

  def call(*a)
    proc { begin; $SAFE = 3; rescue; nil; end; eval(@string) }.call
  end

  def _dump(d = nil)
    @string
  end

  def inspect
    "StringProc.new(#{@string.inspect})"
  end

  def to_json(*args)
    ";e #{_dump}".to_json(args)
  end
end
