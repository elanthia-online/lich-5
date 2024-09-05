# New module SessionVars for variables needed by more than one script but do not need to be saved to the sqlite db
#   (should this be in settings path?)
# 2024-09-05

module SessionVars
  @@svars = Hash.new

  def SessionVars.[](name)
    @@svars[name]
  end

  def SessionVars.[]=(name, val)
    if val.nil?
      @@svars.delete(name)
    else
      @@svars[name] = val
    end
  end

  def SessionVars.list
    @@svars.dup
  end

  def SessionVars.method_missing(arg1, arg2 = '')
    if arg1[-1, 1] == '='
      if arg2.nil?
        @@svars.delete(arg1.to_s.chop)
      else
        @@svars[arg1.to_s.chop] = arg2
      end
    else
      @@svars[arg1.to_s]
    end
  end
end
