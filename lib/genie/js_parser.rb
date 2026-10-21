# frozen_string_literal: true

module Lich
  module Genie
    # The slice of JavaScript syntax the in-Lich stand-in for Remix's Jint 4 engine ({JsRuntime})
    # runs itself: a program of expression statements (`;` or a line break between them, `;`
    # alone is an empty statement) whose expressions are literals (strings with every escape,
    # numbers incl. hex/octal/binary/legacy octal and separators, `-`/`+` before a number,
    # true/false/null), identifiers and calls `name(arg, ...)` whose arguments are the same.
    # That covers every `js`/`jscall` row of the corpus (`doPush("arr","$1")`,
    # `findMaxGlobal("array");`) and simple `<% setVar(..) %>` blocks.
    #
    # Syntax errors are Acornima's (the parser Jint 4 uses), as Jint reports them through
    # JavaScriptException.Message: "<text> (<anonymous>:<line>:<column>)" (genieflow probes):
    # an unterminated string or a malformed number is "Invalid or unexpected token" at its
    # start, a bad escape "Invalid hexadecimal escape sequence" / "Invalid Unicode escape
    # sequence" / "Undefined Unicode code-point" at its backslash, a truncated text "Unexpected
    # end of input", and a token that can never follow / start an expression there
    # "Unexpected string" / "Unexpected number" / "Unexpected identifier 'x'" / "Unexpected token
    # ')'". Tokens are read one ahead, as Acornima does, so a bad token is reported before a
    # grammar error behind it. Anything else (operators, member access, functions, `var`, ...) is
    # valid JavaScript this port cannot run: {JsRuntime::Unsupported}.
    class JsParser
      # A literal value ({JsValue}).
      Literal = Struct.new(:value)
      # An identifier reference.
      Ref = Struct.new(:name, :line, :col)
      # A call of an identifier.
      Call = Struct.new(:name, :line, :col, :args)

      Token = Struct.new(:type, :value, :line, :col, :newline)

      # The source as an array of characters behind the String#[] / #index / #length the scanner
      # uses: String#[] on a non-ASCII UTF-8 string walks it from the start (quadratic scans).
      class Chars
        def initialize(text)
          @chars = text.chars
        end

        def length
          @chars.length
        end

        def [](index, count = nil)
          return @chars[index] if count.nil? && !index.is_a?(Range)

          part = count.nil? ? @chars[index] : @chars[index, count]
          part&.join
        end

        # @return [Integer, nil] where +text+ starts at or after +from+
        def index(text, from)
          (from..(@chars.length - text.length)).find { |i| @chars[i, text.length].join == text }
        end
      end
      private_constant :Chars

      # Calls nested deeper than this (`getVar(getVar(..))`) are {JsRuntime::Unsupported}: the
      # recursive descent (and JsRuntime's evaluation of the tree) would exhaust the stack -- a
      # SystemStackError past ~150 levels on the flow harness's fibers, sooner when the code runs
      # inside nested action dispatch -- where Jint takes thousands (a genieflow probe:
      # 3000 levels run). The corpus nests two.
      MAX_NESTING = 64

      LINE_TERMINATORS = ["\n", "\r", [0x2028].pack('U'), [0x2029].pack('U')].freeze
      # JS WhiteSpace (not LineTerminator).
      SPACES = [0x09, 0x0B, 0x0C, 0x20, 0xA0, 0x1680, *0x2000..0x200A, 0x202F, 0x205F, 0x3000, 0xFEFF].pack('U*').freeze
      # Punctuators that can never continue an expression nor start one (their errors are certain).
      CLOSERS = [')', ']', '}', ':'].freeze
      # Punctuators that can never start a statement (`.` continues one: member access; `...` spreads
      # a call argument).
      NON_STARTERS = [',', '.', '...'].freeze
      # Reserved words (and contextual ones that may start a declaration): never an identifier here.
      KEYWORDS = %w[await async break case catch class const continue debugger default delete do else enum export
                    extends finally for function if implements import in instanceof interface let new package private
                    protected public return static super switch this throw try typeof var void while with yield].freeze
      LITERAL_WORDS = { 'true' => true, 'false' => false, 'null' => JsValue::NULL }.freeze
      SIMPLE_ESCAPES = { 'n' => "\n", 'r' => "\r", 't' => "\t", 'b' => "\b", 'f' => "\f", 'v' => "\v" }.freeze

      # @param source [String]
      # @return [Array<Literal, Ref, Call>] the expression statements, in order
      # @raise [JsRuntime::JsError] a syntax error
      # @raise [JsRuntime::Unsupported] JavaScript outside the slice
      def self.parse(source)
        new(source).program
      end

      def initialize(source)
        @src = Chars.new(source.to_s.scrub(ConfigFile::REPLACEMENT))
        @nesting = 0
        @pos = 0
        @line = 1
        @col = 0 # UTF-16 units since the line start
        advance
      end

      # @return [Array<Literal, Ref, Call>]
      def program
        statements = []
        loop do
          case @tok.type
          when :eof then return statements
          when :punct
            if @tok.value == ';'
              advance
              next
            end
            unexpected_token if CLOSERS.include?(@tok.value) || NON_STARTERS.include?(@tok.value)
            unsupported unless %w[- +].include?(@tok.value)
          end
          statements << expression
          statement_end
        end
      end

      private

      # --- grammar ------------------------------------------------------------------------

      # After an expression statement: `;`, the end, a line break before a token that cannot
      # continue the expression (automatic semicolon insertion), or a certain error.
      def statement_end
        return advance if @tok.type == :punct && @tok.value == ';'
        return if @tok.type == :eof
        return if @tok.newline && (%i[string number ident].include?(@tok.type) || closer?)

        dangling_token
      end

      def expression
        case @tok.type
        when :string, :number then literal(@tok.value)
        when :ident then identifier
        when :punct then signed_number
        else unsupported
        end
      end

      def literal(value)
        advance
        Literal.new(value)
      end

      def identifier
        name = @tok.value
        return literal(LITERAL_WORDS[name]) if LITERAL_WORDS.key?(name)
        return unsupported if KEYWORDS.include?(name)

        line = @tok.line
        col = @tok.col
        advance
        return Ref.new(name, line, col) unless @tok.type == :punct && @tok.value == '('

        advance
        Call.new(name, line, col, nested { arguments })
      end

      def nested
        @nesting += 1
        raise JsRuntime::Unsupported, "calls nested deeper than #{MAX_NESTING}" if @nesting > MAX_NESTING

        yield
      ensure
        @nesting -= 1
      end

      def signed_number
        sign = @tok.value
        unsupported unless %w[- +].include?(sign)
        advance
        unsupported unless @tok.type == :number
        value = @tok.value
        advance
        Literal.new(sign == '-' ? -value : value)
      end

      # The argument list after `(` up to its `)` (a trailing comma is allowed).
      def arguments
        args = []
        loop do
          return close_arguments(args) if punct?(')')
          unexpected_token if closer? || punct?(';') || punct?(',') || punct?('.') # `...` spreads (valid)
          end_of_input if @tok.type == :eof
          args << expression
          next advance if punct?(',')
          return close_arguments(args) if punct?(')')

          dangling_token
        end
      end

      def close_arguments(args)
        advance
        args
      end

      # A token right after a complete expression that is not `;`/`,`/`)`: a certain syntax
      # error if no operator can be it, else JavaScript we do not run.
      def dangling_token
        case @tok.type
        when :eof then end_of_input
        when :string then syntax('Unexpected string')
        when :number then syntax('Unexpected number')
        when :ident
          unsupported if KEYWORDS.include?(@tok.value) || LITERAL_WORDS.key?(@tok.value)
          syntax("Unexpected identifier '#{@tok.value}'")
        else
          unexpected_token if closer? || punct?(';')
          missing_operand
          unsupported
        end
      end

      # `x %>` -- the `%>` of a one-line `<% .. %>` block, which stays in the block (Script.cs:
      # 3737-3745 R): `%` wants an operand and `>` cannot start one, "Unexpected token '>'" at the
      # `>` (genieflow probe; `%=` reads as `%` then `=`, never `>`). Other operator
      # sequences are not modelled.
      def missing_operand
        return unless punct?('%')

        advance
        unexpected_token if punct?('>') && !['>', '='].include?(@src[@pos])
      end

      def punct?(value)
        @tok.type == :punct && @tok.value == value
      end

      def closer?
        @tok.type == :punct && CLOSERS.include?(@tok.value)
      end

      def unexpected_token
        syntax("Unexpected token '#{@tok.value}'")
      end

      def end_of_input
        syntax('Unexpected end of input')
      end

      def syntax(text, line = @tok.line, col = @tok.col)
        raise JsRuntime::JsError, "#{text} (<anonymous>:#{line}:#{col})"
      end

      def unsupported
        raise JsRuntime::Unsupported, 'JavaScript outside the supported slice'
      end

      # --- tokens (read one ahead) ---------------------------------------------------------

      def advance
        newline = skip_blank
        line = @line
        col = @col + 1
        @tok = if @pos >= @src.length then Token.new(:eof, nil, line, col, newline)
               else
                 type, value = read_token(line, col)
                 Token.new(type, value, line, col, newline)
               end
        nil
      end

      # Whitespace and comments. @return [Boolean] whether a line break was skipped
      def skip_blank
        newline = false
        while @pos < @src.length
          char = @src[@pos]
          if LINE_TERMINATORS.include?(char)
            newline = true
            take_line_break
          elsif SPACES.include?(char) then step
          elsif @src[@pos, 2] == '//' then step while @pos < @src.length && !LINE_TERMINATORS.include?(@src[@pos])
          elsif @src[@pos, 2] == '/*' then newline |= block_comment
          else break
          end
        end
        newline
      end

      def block_comment
        close = @src.index('*/', @pos + 2)
        unsupported if close.nil? # Acornima's unterminated-comment message is not modelled
        newline = false
        while @pos < close + 2
          if LINE_TERMINATORS.include?(@src[@pos])
            newline = true
            take_line_break
          else
            step
          end
        end
        newline
      end

      def take_line_break
        @pos += @src[@pos, 2] == "\r\n" ? 2 : 1
        @line += 1
        @col = 0
      end

      def step(count = 1)
        count.times do
          @col += @src[@pos].ord > 0xFFFF ? 2 : 1
          @pos += 1
        end
      end

      def read_token(line, col)
        char = @src[@pos]
        if ['"', "'"].include?(char) then [:string, read_string(char, line, col)]
        elsif char.match?(/[0-9]/) || (char == '.' && @src[@pos + 1].to_s.match?(/[0-9]/)) then [:number, read_number(line, col)]
        elsif char.match?(/[A-Za-z_$]/) then [:ident, read_identifier]
        elsif @src[@pos, 3] == '...'
          step(3)
          [:punct, '...']
        else
          step
          [:punct, char]
        end
      end

      def read_identifier
        start = @pos
        step while @pos < @src.length && @src[@pos].match?(/[A-Za-z0-9_$]/)
        unsupported if @pos < @src.length && (@src[@pos] == '\\' || @src[@pos].ord > 0x7F)
        @src[start...@pos]
      end

      # --- string literals ------------------------------------------------------------------

      def read_string(quote, line, col)
        step
        out = +''
        loop do
          syntax('Invalid or unexpected token', line, col) if @pos >= @src.length
          char = @src[@pos]
          if char == quote
            step
            return out
          end
          syntax('Invalid or unexpected token', line, col) if ["\n", "\r"].include?(char)
          if char == '\\'
            syntax('Invalid or unexpected token', line, col) if @pos + 1 >= @src.length
            out << read_escape
          else
            out << char
            step
          end
        end
      end

      # One escape sequence, the backslash at @pos. @return [String]
      def read_escape
        line = @line
        col = @col + 1
        step
        char = @src[@pos]
        return line_continuation if LINE_TERMINATORS.include?(char)

        step
        if SIMPLE_ESCAPES.key?(char) then SIMPLE_ESCAPES[char]
        elsif char == 'x' then hex_escape(line, col)
        elsif char == 'u' then unicode_escape(line, col)
        elsif char.match?(/[0-7]/) then octal_escape(char)
        else char # \8, \9 and any other character stand for themselves (sloppy mode)
        end
      end

      def line_continuation
        take_line_break
        ''
      end

      def hex_escape(line, col)
        digits = @src[@pos, 2].to_s
        syntax('Invalid hexadecimal escape sequence', line, col) unless digits.match?(/\A[0-9a-fA-F]{2}\z/)
        step(2)
        [digits.to_i(16)].pack('U')
      end

      def unicode_escape(line, col)
        if @src[@pos] == '{'
          close = @src.index('}', @pos)
          digits = close && @src[(@pos + 1)...close]
          syntax('Invalid Unicode escape sequence', line, col) unless digits&.match?(/\A[0-9a-fA-F]+\z/)
          syntax('Undefined Unicode code-point', line, col) if digits.to_i(16) > 0x10FFFF
          step(digits.length + 2)
          return code_point(digits.to_i(16))
        end
        digits = @src[@pos, 4].to_s
        syntax('Invalid Unicode escape sequence', line, col) unless digits.match?(/\A[0-9a-fA-F]{4}\z/)
        step(4)
        code_point(digits.to_i(16))
      end

      # A lone surrogate cannot live in a Ruby UTF-8 string: U+FFFD stands in for it.
      def code_point(value)
        [value.between?(0xD800, 0xDFFF) ? 0xFFFD : value].pack('U')
      end

      # Legacy octal escape (sloppy mode): up to 3 digits from 0-3, up to 2 from 4-7.
      def octal_escape(first)
        digits = first.dup
        max = first <= '3' ? 3 : 2
        while digits.length < max && @src[@pos].to_s.match?(/[0-7]/)
          digits << @src[@pos]
          step
        end
        [digits.to_i(8)].pack('U')
      end

      # --- numeric literals -----------------------------------------------------------------

      # A numeric literal. Acornima's errors (genieflow probes): a malformed literal,
      # or one an identifier character follows, is "Invalid or unexpected token" at its start; a
      # misplaced `_` separator has its own message at the `_` ({separated_digits}); a `_` in a
      # legacy `0nn` literal is "Invalid or unexpected token" at the `_`.
      def read_number(line, col)
        value, integer = numeric_body
        if @pos < @src.length && @src[@pos].match?(/[A-Za-z0-9_$\\]/)
          unsupported if integer && value && @src[@pos] == 'n' # BigInt (no CLR conversion; Jint: "10n" -> "10")
          syntax('Invalid or unexpected token', line, col)
        end
        syntax('Invalid or unexpected token', line, col) if value.nil?
        value
      end

      # @return [Array(Float, Boolean)] the value (nil when malformed) and whether a BigInt
      #   suffix could follow (an integer literal that is not legacy octal/decimal)
      def numeric_body
        prefixed = @src[@pos, 2].to_s.downcase
        return [radix_literal({ '0x' => 16, '0o' => 8, '0b' => 2 }.fetch(prefixed)), true] if %w[0x 0o 0b].include?(prefixed)
        return [legacy_octal, false] if @src[@pos] == '0' && @src[@pos + 1].to_s.match?(/[0-9]/)

        decimal_literal
      end

      def radix_literal(radix)
        step(2)
        digits = separated_digits(radix == 16 ? /[0-9a-fA-F]/ : /[0-#{radix - 1}]/)
        digits.empty? ? nil : digits.to_i(radix).to_f
      end

      # `017` is octal 15, `08` / `019` are decimal (sloppy mode); no separators.
      def legacy_octal
        start = @pos
        step while @pos < @src.length && @src[@pos].match?(/[0-9]/)
        syntax('Invalid or unexpected token', @line, @col + 1) if @src[@pos] == '_'
        digits = @src[start...@pos]
        return digits.to_i(8).to_f if digits.match?(/\A[0-7]+\z/)

        decimal_tail(digits).first
      end

      def decimal_literal
        decimal_tail(separated_digits(/[0-9]/, leading_zero: true))
      end

      # @return [Array(Float, Boolean)]
      def decimal_tail(int_digits)
        text = int_digits.dup
        integer = true
        if @src[@pos] == '.'
          step
          integer = false
          text << '.' << separated_digits(/[0-9]/)
        end
        if @src[@pos].to_s.match?(/[eE]/)
          step
          integer = false
          sign = @src[@pos].to_s.match?(/[+-]/) ? @src[@pos] : ''
          step unless sign.empty?
          exponent = separated_digits(/[0-9]/)
          return [nil, false] if exponent.empty?

          text << "e#{sign}#{exponent}"
        end
        [Float(text.start_with?('.') ? "0#{text}" : text.sub(/\.(?=e|\z)/, '')), integer]
      end

      # A run of digits of +pattern+ with `_` separators: a `_` right after another is "Only one
      # underscore is allowed as numeric separator", after the single leading `0` of a decimal
      # literal (+leading_zero+) "Numeric separator can not be used after leading 0", and a run
      # ending with `_` "Numeric separators are not allowed at the end of numeric literals" -- each
      # at that `_`. A run cannot start with `_` (the literal ends there).
      # @return [String] the digits
      def separated_digits(pattern, leading_zero: false)
        digits = +''
        separator = nil # the column of a `_` just taken
        while @pos < @src.length
          char = @src[@pos]
          if char.match?(pattern)
            digits << char
            separator = nil
          elsif char == '_' && !digits.empty?
            syntax('Only one underscore is allowed as numeric separator', @line, @col + 1) if separator
            syntax('Numeric separator can not be used after leading 0', @line, @col + 1) if leading_zero && digits == '0'
            separator = @col + 1
          else
            break
          end
          step
        end
        syntax('Numeric separators are not allowed at the end of numeric literals', @line, separator) if separator
        digits
      end
    end
  end
end
