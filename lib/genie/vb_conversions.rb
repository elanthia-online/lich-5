# frozen_string_literal: true

module Lich
  module Genie
    # Strict port of VB `Conversions.ToInteger(object)` (Microsoft.VisualBasic.Core; Remix
    # v4.2.4 targets net10.0-windows, Genie4.csproj:3 R -- the genieoracle runs it on .NET 10
    # and .NET 8 with identical answers) for a value read from a Genie variable list:
    # nil (a missing SortedList key) or a String. Unlike a lenient primitive (the removed
    # Numeric.to_integer returned -1 where VB throws), this RAISES {Error} with the exact .NET
    # exception message wherever the runtime throws, so a call site that ports C# which
    # lets the exception escape (EvalShift, Script.cs:3005 R) gets the same outcome.
    #
    # Model (en-US culture, the project convention):
    #   * nil -> 0 (ToInteger(Nothing)).
    #   * `&H`/`&O` after leading ' ' / U+3000 and with >= 1 more char: Convert.ToInt64(rest,
    #     16 or 8) (tight: optional sign, `0x` prefix for hex only, no surrounding blanks; a
    #     `-` is an ArgumentException; > 64 bits overflows; the 64-bit pattern is a
    #     two's-complement long), then a checked Int32 cast.
    #   * otherwise double.Parse(value, AllowLeading/TrailingWhite | Leading/TrailingSign |
    #     Parentheses | DecimalPoint | Thousands | Exponent | CurrencySymbol, en-US), the
    #     NaN / infinity symbols, then Math.Round (half-to-even) and a checked Int32 cast.
    #   * a run of NULs after the whole number grammar is accepted (Number.TrailingZeros) on
    #     the double.Parse path only (genieoracle: `5 \0` = 5; `&H1F\0`, `NaN\0` fail).
    #   * a format failure -> InvalidCastException "Conversion from string "<Left 32>" to
    #     type 'Integer' is not valid."; out of Int32 range / NaN -> OverflowException.
    #
    # Every row of spec/lib/genie/vb_conversions_spec.rb was answered by the real runtime
    # (genieoracle `toint`/`tointmsg`); genie-port-lab/reference/fuzz_vb_toint.rb fuzzes it.
    module VbConversions
      module_function

      INT32_RANGE = (-(2**31))..((2**31) - 1)
      INT64_MIN = -(2**63)
      UINT64_MAX = (2**64) - 1
      OVERFLOW = 'Arithmetic operation resulted in an overflow.'
      UINT64_OVERFLOW = 'Value was either too large or too small for a UInt64.'
      NEGATIVE_BASE = 'String cannot contain a minus sign if the base is not 10.'
      IDEOGRAPHIC_SPACE = [0x3000].pack('U')
      INFINITY_SIGN = [0x221E].pack('U')
      # .NET Number.IsWhite: ' ' and \t \n \v \f \r.
      WHITE = [" ", "\t", "\n", "\v", "\f", "\r"].freeze
      # Symbols double.Parse accepts once the number grammar fails (ordinal ignore-case).
      NON_FINITE = {
        INFINITY_SIGN => Float::INFINITY, "-#{INFINITY_SIGN}" => -Float::INFINITY,
        "+#{INFINITY_SIGN}" => Float::INFINITY, 'nan' => Float::NAN, '+nan' => Float::NAN,
        '-nan' => Float::NAN
      }.freeze

      # @param value [String, nil]
      # @return [Integer]
      # @raise [Error] with the .NET exception message
      def to_integer(value)
        return 0 if value.nil?

        text = value.to_s
        long = hex_or_oct(text)
        return checked_int32(long) unless long.nil?

        double = parse_double(text)
        raise Error, invalid_cast(text) if double.nil?
        raise Error, OVERFLOW if double.nan? || double.infinite?

        checked_int32(double.round(half: :even))
      end

      def invalid_cast(text, type = 'Integer') = "Conversion from string \"#{text[0, 32]}\" to type '#{type}' is not valid."

      # VB `Information.IsNumeric(string)`: an `&H`/`&O` literal (a malformed one is not
      # numeric: IsNumeric swallows the exception), else `double.TryParse(value,
      # NumberStyles.Any, en-US)` -- the same grammar as {to_double}. MathEval.Evaluate's
      # fast path (MathEval.cs:146-147 R): `1,000`, `$5`, `(5)`, `5-`, ` 5 `, `NaN`, `1e400`
      # are numbers; `Infinity` is not.
      # @param value [String, nil]
      # @return [Boolean]
      def numeric?(value)
        return false if value.nil?

        begin
          return true unless hex_or_oct(value.to_s).nil?
        rescue Error
          return false
        end
        !exact_double(value.to_s).nil?
      end

      # VB `Conversions.ToDouble(string)` (en-US): nil -> 0; an `&H`/`&O` literal -> its Int64
      # value; else `double.Parse(value, NumberStyles.Any)`, correctly rounded, overflowing to
      # +-Infinity like .NET Core 3.0+. Used by MathEval (MathEval.cs:147, 748-749 R).
      # @param value [String, nil]
      # @return [Float]
      # @raise [Error] InvalidCastException's message on a format failure (and the
      #   Convert.ToInt64 messages of a malformed `&H`/`&O` literal)
      def to_double(value)
        return 0.0 if value.nil?

        text = value.to_s
        long = hex_or_oct(text)
        return long.to_f unless long.nil?

        double = exact_double(text)
        raise Error, invalid_cast(text, 'Double') if double.nil?

        double
      end

      # VB `Conversions.ToInteger(double)`: `checked((int)Math.Round(value))` -- half-to-even,
      # NaN / out-of-Int32 overflow (MathEval `!`, round's digits; MathEval.cs:231, 331 R).
      # @param value [Float]
      # @return [Integer]
      # @raise [Error] OverflowException's message
      def double_to_integer(value)
        raise Error, OVERFLOW unless value.finite?

        checked_int32(value.round(half: :even))
      end

      # VB `Conversions.ToLong(double)`: `checked((long)Math.Round(value))` (MathEval `\`,
      # MathEval.cs:217 R).
      # @param value [Float]
      # @return [Integer]
      # @raise [Error] OverflowException's message
      def double_to_long(value)
        raise Error, OVERFLOW unless value.finite?

        long = value.round(half: :even)
        raise Error, OVERFLOW unless long.between?(INT64_MIN, -INT64_MIN - 1)

        long
      end

      # double.Parse(text, NumberStyles.Any, en-US), correctly rounded: nil on a format
      # failure (the number grammar of {scan_number}, then the NaN / infinity symbols).
      def exact_double(text)
        number = scan_number(text, exact: true)
        return number unless number.nil?

        NON_FINITE[text.sub(/\A[[:space:]]+/, '').sub(/[[:space:]]+\z/, '').downcase]
      end

      def checked_int32(number)
        raise Error, OVERFLOW unless INT32_RANGE.cover?(number)

        number
      end

      # Utils.IsHexOrOctValue: nil when the text is not an `&H`/`&O` literal.
      def hex_or_oct(text)
        i = 0
        while i < text.length
          ch = text[i]
          if ch == '&' && i + 2 < text.length
            radix = { 'h' => 16, 'o' => 8 }[text[i + 1].downcase]
            raise Error, invalid_cast(text) if radix.nil?

            return to_int64(text[(i + 2)..], radix, text)
          end
          return nil unless [' ', IDEOGRAPHIC_SPACE].include?(ch)

          i += 1
        end
        nil
      end

      # Convert.ToInt64(digits, radix): ParseNumbers.StringToLong with IsTight.
      def to_int64(digits, radix, text)
        i = 0
        if digits[i] == '-'
          raise Error, NEGATIVE_BASE
        elsif digits[i] == '+'
          i += 1
        end
        i += 2 if radix == 16 && digits[i] == '0' && digits[i + 1]&.match?(/[xX]/)
        # GrabLongs reads the longest digit run (overflowing as it goes), THEN the
        # tight check rejects an empty run or trailing junk.
        run = digits[i..].to_s[radix == 16 ? /\A[0-9a-fA-F]*/ : /\A[0-7]*/]
        number = run.to_i(radix)
        raise Error, UINT64_OVERFLOW if number > UINT64_MAX
        raise Error, invalid_cast(text) if run.empty? || i + run.length < digits.length

        number > -INT64_MIN - 1 ? number - (2**64) : number
      end

      # double.Parse with VB's ParseDouble NumberStyles (Number.TryParseNumber state
      # machine, en-US: sign "+"/"-", currency "$", "." decimal, "," group). nil on a
      # format failure.
      def parse_double(text)
        number = scan_number(text)
        return number unless number.nil?

        # The symbol fallback trims with String.Trim() (char.IsWhiteSpace, U+3000
        # included), unlike the number grammar's Number.IsWhite.
        NON_FINITE[text.sub(/\A[[:space:]]+/, '').sub(/[[:space:]]+\z/, '').downcase]
      end

      def scan_number(text, exact: false)
        state = { sign: false, parens: false, currency: false, negative: false }
        i = scan_leading(text, 0, state)
        int_digits = +''
        frac_digits = +''
        decimal = false
        while i < text.length
          ch = text[i]
          if ch.match?(/[0-9]/)
            decimal ? frac_digits << ch : int_digits << ch
          elsif ch == '.' && !decimal
            decimal = true
          elsif ch == ',' && !decimal && !int_digits.empty?
            nil # group separator, only after a digit and before the decimal point
          else
            break
          end
          i += 1
        end
        return nil if int_digits.empty? && frac_digits.empty?

        exponent, i = scan_exponent(text, i)
        i = scan_trailing(text, i, state)
        # Number.TryStringToNumber: unconsumed text passes when it is all NULs
        # (Number.TrailingZeros) -- "5 <NUL><NUL>" is 5, "5<NUL> " is not.
        i += 1 while text[i] == "\0"
        return nil if state[:parens] || i < text.length

        magnitude = exact ? exact_magnitude(int_digits, frac_digits, exponent) : int32_magnitude(int_digits, frac_digits, exponent)
        state[:negative] ? -magnitude : magnitude
      end

      def scan_leading(text, i, state)
        while i < text.length
          ch = text[i]
          if WHITE.include?(ch) && (!state[:sign] || state[:currency])
            nil
          elsif !state[:sign] && ['+', '-'].include?(ch)
            state[:sign] = true
            state[:negative] = ch == '-'
          elsif ch == '(' && !state[:sign]
            state[:sign] = state[:parens] = state[:negative] = true
          elsif ch == '$' && !state[:currency]
            state[:currency] = true
          else
            break
          end
          i += 1
        end
        i
      end

      # `e`/`E`, optional sign, digits; without digits the `e` is not consumed.
      def scan_exponent(text, i)
        return [0, i] unless ['e', 'E'].include?(text[i])

        j = i + 1
        negative = text[j] == '-'
        j += 1 if ['+', '-'].include?(text[j])
        start = j
        j += 1 while j < text.length && text[j].match?(/[0-9]/)
        return [0, i] if j == start

        value = text[start...j].to_i
        [negative ? -value : value, j]
      end

      def scan_trailing(text, i, state)
        while i < text.length
          ch = text[i]
          if WHITE.include?(ch)
            nil
          elsif !state[:sign] && ['+', '-'].include?(ch)
            state[:sign] = true
            state[:negative] = ch == '-'
          elsif ch == ')' && state[:parens]
            state[:parens] = false
          elsif ch == '$' && !state[:currency]
            state[:currency] = true
          else
            break
          end
          i += 1
        end
        i
      end

      # The correctly rounded double of 0.<digits> scaled, without letting Ruby's
      # Float() see an out-of-range exponent (it warns). Anything >= 1e11 overflows
      # Int32 anyway and anything < 0.1 rounds to 0, so those are decided by the
      # position of the first significant digit.
      def int32_magnitude(int_digits, frac_digits, exponent)
        digits = int_digits + frac_digits
        first = digits.index(/[1-9]/)
        return 0.0 if first.nil?

        lead = int_digits.length - first - 1 + exponent # power of ten of the first digit
        return Float::INFINITY if lead > 11
        return 0.0 if lead < -2

        Float("#{digits[first..]}e#{lead - (digits.length - first - 1)}")
      end

      # The correctly rounded double of the decimal <int_digits>.<frac_digits>e<exponent>
      # (Ruby's strtod is correctly rounded, like .NET Core 3.0+'s double.Parse), overflowing
      # to Infinity and underflowing to 0 without handing Float() an absurd exponent.
      def exact_magnitude(int_digits, frac_digits, exponent)
        digits = int_digits + frac_digits
        first = digits.index(/[1-9]/)
        return 0.0 if first.nil?

        lead = int_digits.length - first - 1 + exponent # power of ten of the first digit
        return Float::INFINITY if lead > 309
        return 0.0 if lead < -400

        Float("#{digits[first..]}e#{lead - (digits.length - first - 1)}")
      end
    end
  end
end
