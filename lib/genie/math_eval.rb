# frozen_string_literal: true

module Lich
  module Genie
    # Arithmetic evaluator backing `evalmath` / `#evalmath`: a LITERAL port of Remix
    # Script/MathEval.cs (MathEval.cs is byte-identical to upstream's). Each method
    # below names the C# member it ports; read them side by side.
    #
    # Evaluate (MathEval.cs:141-155 R): a VB-numeric expression (`1,000`, `$5`, `(5)`, `5-`,
    # `NaN`, `&H10`) converts straight through Conversions.ToDouble; anything else goes
    # through calc_scan (the 7-state table lexer, MathEval.cs:418-547 R) and the recursive
    # level0..level6 descent (MathEval.cs:555-798 R), which evaluates the FIRST expression and
    # ignores whatever tokens are left (`1+1 = 2` is 2, `3!!` is 6, `5abc` is 0: `5abc` lexes
    # as one identifier). Every exception becomes InvalidCastException("Invalid expression:
    # " + expression) -- here an {Error} with that message.
    #
    # Quirks that fall out of the port (all genieoracle-verified):
    #   * `_` and `#` are punctuation, a digit ends an identifier: `log10(1000)` throws
    #     (`log` then the number 10), `_x` throws, `1e5` is the identifier `1e` (0) then 5;
    #   * `&` and `(` after an operand are LEVEL5 postfix operators with no calc_op case:
    #     `2 & 3` and `2(3)` are 0;
    #   * unary +/- binds looser than `!` and only once (`--5` throws);
    #   * `^` is left-associative; `\` is Int64 division of the half-to-even rounded
    #     operands; `%` is C#'s fmod; `log` is base 10.
    module MathEval
      # m_funcs (MathEval.cs:63 R); Array.Sort + BinarySearch = membership.
      FUNCTIONS = %w[
        sin cos tan arcsin arccos arctan sqrt max min
        floor ceiling log log10 ln round abs neg pos
      ].freeze

      ALPHA = '_ABCDEFGHIJKLMNOPQRSTUVWXYZ'
      DIGITS = '#0123456789'

      # init_operators (MathEval.cs:69-139 R): [token, precedence level]. NONE = 0 .. LEVEL5 = 6
      # in C#; the numbers here are the LEVELn suffixes (`)` is LEVEL0).
      OPERATORS = [
        ['-', 1], ['+', 1], ['*', 2], ['/', 2], ['\\', 2], ['%', 2], ['^', 3],
        ['!', 5], ['&', 5], ['-', 4], ['+', 4], ['(', 5], [')', 0]
      ].freeze

      # m_colstring = (char)9 + " " + ".()" + every operator token (MathEval.cs:542-544 R).
      COLSTRING = "\t .()#{OPERATORS.map(&:first).join}".freeze

      # init's state table (MathEval.cs:538 R): STATE[state - 1][column - 1].
      STATE = [
        [2, 4, 1, 1, 4, 6, 7],
        [2, 3, 3, 3, 3, 3, 3],
        [1, 1, 1, 1, 1, 1, 1],
        [2, 4, 5, 5, 4, 5, 5],
        [1, 1, 1, 1, 1, 1, 1],
        [1, 1, 1, 1, 1, 1, 1],
        [1, 1, 1, 1, 1, 1, 1]
      ].freeze

      # ClassSymbol (token text + TOKENCLASS).
      Token = Struct.new(:text, :cls)

      # Math.Round(value, digits)'s RoundPower10Double table (digits 0..15).
      ROUND_POWERS = (0..15).map { |k| 10.0**k }.freeze

      module_function

      # Evaluate (MathEval.cs:141-155 R).
      # @param expression [String]
      # @return [Float]
      # @raise [Error] "Invalid expression: <expression>" (InvalidCastException in Remix)
      def evaluate(expression)
        text = Text.net_string(expression)
        return VbConversions.to_double(text) if VbConversions.numeric?(text)

        Parser.new(calc_scan(text)).level0
      rescue StandardError
        raise Error, "Invalid expression: #{text || expression}"
      end

      # calc_scan (MathEval.cs:418-534 R): the table-driven lexer.
      # @param line [String]
      # @return [Array<Token>]
      def calc_scan(line)
        chars = "#{line} ".chars # a space as the end marker
        symbols = []
        sp = 0
        cp = 0
        lex_state = 1
        while cp <= chars.length - 1
          lex_state = STATE[lex_state - 1][column(chars[cp]) - 1]
          case lex_state
          when 3 # function or variable end state
            text = chars[sp...cp].join
            symbols << Token.new(text, FUNCTIONS.include?(text.downcase) ? :keyword : :identifier)
            lex_state = 1
            cp -= 1
          when 5 # number end state
            symbols << Token.new(chars[sp...cp].join, :number)
            lex_state = 1
            cp -= 1
          when 6 # punctuation end state
            symbols << Token.new(chars[sp..cp].join, :punctuation)
            lex_state = 1
          when 7 # operator end state
            symbols << Token.new(chars[sp..cp].join, :operator)
            lex_state = 1
          end
          cp += 1
          sp = cp if lex_state == 1
        end
        symbols
      end

      # The input column of +char+ (MathEval.cs:435-465 R): 1 letter, 2 digit, 3 tab, 4 space,
      # 5 '.', 6 punctuation, 7 operator (incl. parentheses). char.ToUpper is en-US's simple
      # mapping, so the dotless i (U+0131) and the long s (U+017F) are letters.
      def column(char)
        index = COLSTRING.index(char)
        return index + 3 > 5 ? 7 : index + 3 if index

        upper = Text.net_upcase(char)
        if ALPHA.index(upper).to_i.positive? then 1
        elsif DIGITS.index(upper).to_i.positive? then 2
        else 6
        end
      end

      # The level0..level6 descent (MathEval.cs:555-798 R) over one token queue.
      class Parser
        def initialize(tokens)
          @tokens = tokens
        end

        # level0 (MathEval.cs:555-558 R)
        def level0
          level1
        end

        private

        def peek
          @tokens.first
        end

        # Queue.Dequeue: InvalidOperationException on an empty queue.
        def dequeue
          raise Error, 'Queue empty.' if @tokens.empty?

          @tokens.shift
        end

        # is_operator (MathEval.cs:383-403 R): the operator with this token AND level.
        def operator(token, level)
          OPERATORS.find { |text, lvl| text == token.text && lvl == level }
        end

        # level1 / level1_prime (MathEval.cs:560-586 R): binary + -
        def level1
          result = level2
          while (token = peek) && (op = operator(token, 1))
            dequeue
            result = MathEval.calc_op(op, result, level2)
          end
          result
        end

        # level2 / level2_prime (MathEval.cs:588-615 R): binary * / \ %
        def level2
          result = level3
          while (token = peek) && (op = operator(token, 2))
            dequeue
            result = MathEval.calc_op(op, result, level3)
          end
          result
        end

        # level3 / level3_prime (MathEval.cs:617-643 R): binary ^, left-associative
        def level3
          result = level4
          while (token = peek) && (op = operator(token, 3))
            dequeue
            result = MathEval.calc_op(op, result, level4)
          end
          result
        end

        # level4 / level4_prime (MathEval.cs:645-672 R): one unary + -
        def level4
          token = peek
          raise Error, 'Invalid expression.' if token.nil?

          op = operator(token, 4)
          return level5 unless op

          dequeue
          MathEval.calc_op(op, level5)
        end

        # level5 / level5_prime (MathEval.cs:674-701 R): one postfix LEVEL5 operator
        # (`!`, and `&` / `(`, which calc_op turns into 0)
        def level5
          result = level6
          token = peek
          return result if token.nil?

          op = operator(token, 5)
          return result unless op

          dequeue
          MathEval.calc_op(op, result)
        end

        # level6 (MathEval.cs:703-758 R): ( expr ) | identifier | function | number
        def level6
          token = peek
          raise Error, 'Invalid expression.' if token.nil?

          if token.text == '('
            dequeue
            value = level0
            raise Error, 'Invalid expression.' unless dequeue.text == ')'

            return value
          end

          case token.cls
          when :identifier
            dequeue
            MathEval.identifier(token.text)
          when :keyword
            dequeue
            MathEval.calc_function(token.text, arguments)
          when :number
            dequeue
            VbConversions.to_double(token.text)
          else
            raise Error, 'Invalid expression.'
          end
        end

        # arguments (MathEval.cs:760-798 R): `(` expr {`,` expr} `)`
        def arguments
          token = peek
          raise Error, 'Invalid expression.' unless token&.text == '('

          dequeue
          args = [level0]
          token = dequeue
          until token.text == ')'
            raise Error, 'Invalid expression.' unless token.text == ','

            args << level0
            token = dequeue
          end
          args
        end
      end

      # calc_op (MathEval.cs:157-240 R). +op+ is an OPERATORS entry.
      # @return [Float]
      def calc_op(op, operand1, operand2 = 0.0)
        token, level = op
        case token
        when '^' then power(operand1, operand2)
        when '+'
          return operand2 + operand1 if level == 1
          return operand1 if level == 4

          0.0
        when '-'
          return operand1 - operand2 if level == 1
          return -1 * operand1 if level == 4

          0.0
        when '*' then operand2 * operand1
        when '/' then operand1 / operand2
        when '\\' then integer_divide(operand1, operand2)
        when '%' then Numeric.double_remainder(operand1, operand2)
        when '!' then factorial(operand1)
        else 0.0 # `&`, `(`, `)`: registered operators with no case
        end
      end

      # `Conversions.ToLong(op1) / Conversions.ToLong(op2)` (MathEval.cs:217 R): C# Int64
      # division, truncating toward zero; a zero divisor and MinValue / -1 throw.
      def integer_divide(operand1, operand2)
        dividend = VbConversions.double_to_long(operand1)
        divisor = VbConversions.double_to_long(operand2)
        raise Error, 'Attempted to divide by zero.' if divisor.zero?

        quotient = dividend.abs / divisor.abs
        quotient = -quotient if dividend.negative? != divisor.negative?
        raise Error, VbConversions::OVERFLOW if quotient > -VbConversions::INT64_MIN - 1

        quotient.to_f
      end

      # The `!` case (MathEval.cs:225-236 R): res = 1, then for i = ToInteger(operand1)
      # down to 1 res *= i -- only when operand1 > 1. Once res is infinite it stays so.
      def factorial(operand)
        result = 1.0
        return result unless operand > 1

        i = VbConversions.double_to_integer(operand)
        while i >= 1 && result.finite?
          result *= i
          i -= 1
        end
        result
      end

      # C# Math.Pow: Pow(1, y) == 1 and Pow(x, 0) == 1 for ANY y/x (NaN included); otherwise
      # NaN if either operand is NaN, or a FINITE negative base with a non-integer exponent;
      # Pow(-Infinity, y) for a non-integer y is +Infinity (y > 0) or +0 (y < 0) (Ruby's ** would
      # answer a Complex there).
      def power(base, exp)
        # Exact 1.0 / 0.0 comparisons are deliberate -- C# Math.Pow special-cases them.
        return 1.0 if base == 1.0 || exp.zero? # rubocop:disable Lint/FloatComparison
        return Float::NAN if base.nan? || exp.nan?

        if base.negative? && exp.finite? && exp != exp.to_i
          return Float::NAN if base.finite?

          return exp.positive? ? Float::INFINITY : 0.0
        end

        (base**exp).to_f
      end

      # identifier (MathEval.cs:358-381 R): e, pi, anything else 0.
      def identifier(token)
        case token.downcase
        when 'e' then Math::E
        when 'pi' then Math::PI
        else 0.0
        end
      end

      # calc_function (MathEval.cs:242-356 R) over System.Math: a domain error is NaN (Ruby's
      # Math raises), NaN/Infinity pass through floor/ceiling/round, IEEE -0 is kept.
      # @param func [String]
      # @param args [Array<Float>] at least one
      # @return [Float]
      def calc_function(func, args)
        x = args[0]
        case func.downcase
        when 'cos' then Math.cos(x)
        when 'sin' then Math.sin(x)
        when 'tan' then Math.tan(x)
        when 'floor' then x.finite? ? signed_zero(x.floor.to_f, x) : x
        when 'ceiling' then x.finite? ? signed_zero(x.ceil.to_f, x) : x
        when 'max' then args.drop(1).reduce(x) { |acc, v| net_max(acc, v) }
        when 'min' then args.drop(1).reduce(x) { |acc, v| net_min(acc, v) }
        when 'arcsin' then Math.asin(x)
        when 'arccos' then Math.acos(x)
        when 'arctan' then Math.atan(x)
        when 'sqrt' then x.zero? ? x : Math.sqrt(x) # sqrt(-0) = -0 (IEEE)
        when 'log', 'log10' then Math.log10(x)
        when 'abs' then x.abs
        when 'round' then args.length == 2 ? round_digits(x, VbConversions.double_to_integer(args[1])) : round_even(x)
        when 'ln' then Math.log(x)
        when 'neg' then -1 * x
        when 'pos' then +1 * x
        else 0.0
        end
      rescue Math::DomainError
        Float::NAN
      end

      # .NET Core Math.Max(double, double) (IEEE 754:2019 maximum): NaN wins, +0 > -0.
      def net_max(val1, val2)
        if val1 != val2
          return val1 if val1.nan?

          return val2 < val1 ? val1 : val2
        end
        negative?(val2) ? val1 : val2
      end

      # .NET Core Math.Min(double, double): NaN wins, -0 < +0.
      def net_min(val1, val2)
        if val1 != val2
          return val1 if val1.nan?

          return val1 < val2 ? val1 : val2
        end
        negative?(val1) ? val1 : val2
      end

      # double.IsNegative: the sign bit (so -0.0 and -NaN count).
      def negative?(value)
        value.negative? || (value.zero? && (1.0 / value).negative?)
      end

      # Math.Round(double): half-to-even, NaN/Infinity unchanged, sign of a zero result kept.
      def round_even(value)
        return value unless value.finite?

        signed_zero(value.round(half: :even).to_f, value)
      end

      # Math.Round(double, int digits) (.NET Core): digits outside 0..15 throw; below 1e16
      # the value is scaled by 10^digits, rounded half-to-even and scaled back.
      def round_digits(value, digits)
        raise Error, "Rounding digits must be between 0 and 15, inclusive. (Parameter 'digits')" unless digits.between?(0, 15)
        return value unless value.abs < 1e16

        power10 = ROUND_POWERS[digits]
        round_even(value * power10) / power10
      end

      # C# Math.Floor/Ceiling/Round keep IEEE negative zero: rounding a negative value to 0
      # yields -0.0 (format_double renders "-0"). Ruby's Integer#to_f drops that sign.
      def signed_zero(result, source)
        return result unless result.zero?

        negative?(source) ? -0.0 : 0.0
      end
    end
  end
end
