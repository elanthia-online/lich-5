# frozen_string_literal: true

module Lich
  module Genie
    # Backs the `math` and `counter` script verbs and `#math`. This is a faithful port of
    # Remix Utility.MathCalc (Utility/Utility.cs:883-955 R) and is DISTINCT from
    # {MathEval}, which backs only `evalmath`.
    #
    # Genie quirk preserved: the argument is clamped to >= 0 (Utility.cs:887-890 R), so
    # `math x subtract -5` subtracts 0, not -5, and an unparseable argument
    # (StringToDouble -> -1) acts as 0.
    module MathCalc
      module_function

      # @param value [Numeric] the current value of the target variable
      # @param expression [String] e.g. "add 5", "subtract 2", "set 10", "mod 3"
      # @return [Float] the new value
      # @raise [Error] on an unrecognized operation keyword
      def calc(value, expression)
        keyword = Text.keyword_string(expression).downcase
        arg = Numeric.string_to_double(Text.argument_string(expression))
        arg = 0.0 if arg < 0 # Genie quirk: negative args clamp to 0
        v = value.to_f

        case keyword
        when 'add', '+'
          v + arg
        when 'sub', 'substract', 'subtract', '-'
          v - arg
        when 'set', '='
          arg
        when 'multiply', '*'
          v * arg
        when 'divide', '/'
          # Remix skips a zero divisor: `if (dNumber != 0) dValue = dValue / dNumber;`
          # (Utility.cs:928 R; upstream divides and yields Infinity). NaN != 0, so NaN divides.
          arg.zero? ? v : v / arg
        when 'mod', 'modulus', '%'
          # C# double `%` (Utility.cs:932-946 R): dividend's sign, x % 0 = NaN (not an
          # exception), but a 0 value short-circuits to 0 first.
          v != 0 ? Numeric.double_remainder(v, arg) : 0.0
        else
          raise Error, "Invalid #MATH expression: #{expression}"
        end
      end
    end
  end
end
