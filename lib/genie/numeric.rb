# frozen_string_literal: true

module Lich
  module Genie
    # Numeric coercion/formatting helpers reproducing the .NET/VB semantics the
    # Genie engine relies on. See docs/genie-engine/expressions-spec.md "Cross-cutting".
    module Numeric
      module_function

      # .NET (net6, en-US) renders infinity as U+221E. Built from the codepoint so the
      # source stays ASCII (the AsciiOnlySource cop rejects even a \u escape that yields
      # a non-ASCII char) while emitting exactly what Genie's double.ToString() produces.
      INFINITY_SIGN = [0x221E].pack('U')

      # The grammar .NET's `double.Parse(s, en-US)` accepts under its default
      # NumberStyles (Float | AllowThousands): an optional sign, then digits with
      # lenient `,` group separators in the INTEGER part only (`1,23`, `12,34`,
      # `1,,2` all parse), an optional fraction, and an optional exponent -- OR a
      # leading-dot fraction (`.5`). Verified against the real evaluator via the s2d
      # oracle. Validating with this FIRST is what keeps us faithful: Ruby's `Float()`
      # would otherwise (wrongly, vs Genie) accept `0x1F`->31, `1_000`->1000, and
      # `Infinity`, and would misparse `1.5,3` instead of rejecting it.
      S2D_GRAMMAR = /\A[+-]?(?:\d[\d,]*(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?\z/
      # .NET parses "NaN" (case-insensitive, optional sign) to NaN, but NOT "Infinity".
      S2D_NAN = /\A[+-]?nan\z/i
      # ... and en-US's PositiveInfinitySymbol, U+221E, alone with an optional sign (genieoracle
      # s2d: "-<inf>" is -Infinity; "--<inf>", "1<inf>", "<inf>-", ".<inf>", "<inf>e5" fail).
      S2D_INFINITY = /\A([+-]?)#{INFINITY_SIGN}\z/

      # .NET's Number.IsWhite (U+0009..U+000D, space): the only white the number grammar skips
      # around a number; a trailing run of NULs after it is allowed too (Number.TrailingZeros).
      NUMBER_LEADING = /\A[\t\n\v\f\r ]+/
      NUMBER_TRAILING = /[\t\n\v\f\r ]*\0*\z/

      # Port of Utility.StringToDouble (Utility.cs:609): en-US `double.Parse`, returning
      # -1.0 (NOT 0) on nil/failure. This drives numeric COMPARISONS in Eval, so a
      # too-lenient parse changes real script branching (e.g. comparing `0x1F`).
      #
      # @param str [String, nil]
      # @return [Float]
      def string_to_double(str)
        net_double(str) || -1.0
      end

      # en-US `double.TryParse(s)` / `double.Parse(s)` (NumberStyles.Float | AllowThousands):
      # the number grammar with only Number.IsWhite around it (a leading NUL fails, trailing
      # NULs pass: genieoracle s2d), else -- Number.TryParseFloat's fallback -- the NaN /
      # U+221E symbols on the String.Trim()med text (char.IsWhiteSpace: U+00A0, U+3000 ...).
      # @param str [String, nil]
      # @return [Float, nil] nil where TryParse returns false
      def net_double(str)
        return nil if str.nil?

        text = str.to_s
        number = text.sub(NUMBER_LEADING, '').sub(NUMBER_TRAILING, '')
        return Float(number.delete(',')) if number.match?(S2D_GRAMMAR)

        symbol = text.sub(/\A[[:space:]]+/, '').sub(/[[:space:]]+\z/, '')
        return Float::NAN if symbol.match?(S2D_NAN)

        infinity = S2D_INFINITY.match(symbol)
        infinity && (infinity[1] == '-' ? -Float::INFINITY : Float::INFINITY)
      rescue ArgumentError, TypeError, EncodingError
        nil
      end

      # DateTime.AddMilliseconds' bound (MaxTicks / TicksPerMillisecond, .NET 10): a larger |value|
      # throws ArgumentOutOfRangeException before any arithmetic.
      MAX_MILLISECONDS = 315_537_897_599_999
      ADD_OUT_OF_RANGE = "Value to add was out of range. (Parameter 'value')"
      ADD_UNREPRESENTABLE = "The added or subtracted value results in an un-representable DateTime. (Parameter 'value')"

      # Why DateTime.Now.AddMilliseconds(+ms+) would throw (.NET 10 AddUnits, then AddTicks), or
      # nil: |ms| past MaxMillis (an infinity included), else a result outside years 1..9999. A
      # NaN is 0 ticks ((long)NaN saturates to 0 since .NET 9), so it never throws.
      # @param ms [Float]
      # @param now [Time] DateTime.Now
      # @return [String, nil] the .NET message
      def add_milliseconds_fault(ms, now: Time.now)
        return nil if ms.nan?
        return ADD_OUT_OF_RANGE if ms.abs > MAX_MILLISECONDS
        return ADD_UNREPRESENTABLE unless (now + (ms / 1000.0)).year.between?(1, 9999)

        nil
      end

      # Port of Utility.StringToInteger (Utility.cs:682-704 R): en-US `int.Parse`; a value
      # that is not positive, a parse failure and nil are all -1 (EvalRandom's bounds).
      # @param str [String, nil]
      # @return [Integer]
      def string_to_integer(str)
        value = net_int32(str)
        value&.positive? ? value : -1
      end

      # C# double `%` (IEEE fmod): truncated remainder carrying the DIVIDEND's sign, with
      # `x % 0 => NaN` (never an exception). Used by MathEval `%` (MathEval.cs:222 R) and
      # MathCalc `mod` (Utility.cs:932-946 R). Ruby's Float#remainder raises
      # ZeroDivisionError on a 0 divisor, and returns 0.0 when the DIVISOR dwarfs the
      # dividend (`-95 % 24^21` -> 0.0 instead of -95). In that case trunc(lhs/rhs) is 0,
      # so the remainder is exactly the dividend -- special-case it; otherwise
      # Float#remainder is precise (and beats a subtract-formula, which loses precision for
      # large dividends like `77^12 % 83`). Both edges were caught by the Genie4
      # differential fuzzer (genie-port-lab/reference/fuzz_oracle.rb); NaN/Infinity
      # operands follow fmod (NaN, except finite % Infinity = the dividend; an infinite
      # dividend is NaN whatever the divisor, Infinity included).
      #
      # @param lhs [Float] @param rhs [Float] @return [Float]
      def double_remainder(lhs, rhs)
        return Float::NAN if rhs.zero? || lhs.infinite?
        return lhs if lhs.abs < rhs.abs

        lhs.remainder(rhs)
      end

      # int.TryParse(s) (NumberStyles.Integer, en-US): optional leading/trailing white
      # space (U+0009-U+000D, U+0020), one optional sign, ASCII digits, then optional
      # trailing NULs (.NET number parsing ignores them), within Int32.
      NET_INT32 = /\A[\t\n\v\f\r ]*([+-]?)([0-9]+)[\t\n\v\f\r ]*\0*\z/.freeze

      # @param str [String, nil]
      # @return [Integer, nil] the value, or nil where int.TryParse returns false
      def net_int32(str)
        match = str.to_s.match(NET_INT32)
        return nil unless match

        value = Integer(match[2], 10) * (match[1] == '-' ? -1 : 1)
        value.between?(-2_147_483_648, 2_147_483_647) ? value : nil
      end

      # Stringify a double byte-for-byte as .NET's default double.ToString() (net6,
      # en-US) does -- which is what Genie's `evalmath`/`math` store back into vars
      # (Command.cs EvalMath). .NET uses the SHORTEST round-trippable digits, fixed-point
      # notation when the leading digit's power-of-ten exponent is in [-4, 16], and
      # scientific ("1.5E+30", "1E-05", min 2 exponent digits) otherwise. Ruby's
      # Float#to_s yields the same shortest DIGITS, so we reuse them and re-lay-out.
      # Verified byte-exact against the real Genie4 evaluator via the differential fuzzer
      # (genie-port-lab/reference/fuzz_format.rb).
      #
      # @param value [Numeric]
      # @return [String]
      def format_double(value)
        f = value.to_f
        return 'NaN' if f.nan?
        return f.positive? ? INFINITY_SIGN : "-#{INFINITY_SIGN}" if f.infinite?
        return (1.0 / f).negative? ? '-0' : '0' if f.zero? # preserve -0 like .NET

        digits, exp = shortest_digits(f.abs) # value == d.igits * 10**exp
        body = exp.between?(-4, 16) ? fixed_notation(digits, exp) : scientific_notation(digits, exp)
        f.negative? ? "-#{body}" : body
      end

      # Shortest significant digits (no dot, no leading/trailing zeros) of a positive
      # finite double, plus the power-of-ten exponent of the FIRST digit. Reuses Ruby's
      # shortest Float#to_s. @return [[String, Integer]]
      def shortest_digits(x)
        str = x.to_s
        mantissa, sci = str.include?('e') ? str.split('e') : [str, '0']
        intpart, frac = mantissa.split('.')
        digits = intpart + (frac || '')
        exp = sci.to_i + intpart.length - 1 # exponent of the first char of `digits`
        lead = digits.length - digits.sub(/\A0+/, '').length
        digits = digits.sub(/\A0+/, '').sub(/0+\z/, '')
        digits = '0' if digits.empty?
        [digits, exp - lead]
      end

      def fixed_notation(digits, exp)
        if exp.negative?
          "0.#{'0' * (-exp - 1)}#{digits}"
        elsif digits.length <= exp + 1
          digits + ('0' * (exp + 1 - digits.length))
        else
          "#{digits[0, exp + 1]}.#{digits[(exp + 1)..]}"
        end
      end

      def scientific_notation(digits, exp)
        mantissa = digits.length > 1 ? "#{digits[0]}.#{digits[1..]}" : digits
        "#{mantissa}E#{exp.negative? ? '-' : '+'}#{format('%02d', exp.abs)}"
      end
    end
  end
end
