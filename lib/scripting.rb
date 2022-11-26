class Scripting
  def script
    Proc.new {}.binding
  end
end
def _script
  Proc.new {}.binding
end
