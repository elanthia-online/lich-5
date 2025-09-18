# break out module UserVars
# 2024-06-13

module Lich
  module Common
    module UserVars
      def UserVars.list
        Vars.list
      end

      def UserVars.method_missing(*args)
        Vars.method_missing(*args)
      end

      def UserVars.change(var_name, value, _t = nil)
        Vars[var_name] = value
      end

      def UserVars.add(var_name, value, _t = nil)
        Vars[var_name] = Vars[var_name].split(', ').push(value).join(', ')
      end

      def UserVars.delete(var_name, _t = nil)
        Vars[var_name] = nil
      end

      def UserVars.list_global
        Array.new
      end

      def UserVars.list_char
        Vars.list
      end
    end
  end
end
