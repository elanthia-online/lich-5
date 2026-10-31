# frozen_string_literal: true

require 'digest'

module Lich
  module Genie
    # A JavaScript program split into its top-level function declarations and the rest, for the
    # in-Lich stand-in for Remix's Jint 4 engine ({JsRuntime}). Each declaration
    # `function name(params) { ... }` is cut out and identified by the SHA-256 of its normalised
    # text ({Declaration#fingerprint}): comments removed and every run of white space collapsed to
    # one space -- or to one line break when the run holds a line terminator, so automatic
    # semicolon insertion cannot differ -- with string and regular-expression literals kept
    # verbatim. Two declarations with the same fingerprint therefore are the same JavaScript
    # (every published js_arrays.js version is recognised function by function,
    # whatever its comments, indentation or line breaks). The rest of the program (the
    # declarations blanked out, line breaks and columns kept) goes to {JsParser}.
    #
    # Only the tokens matter here, not the grammar: strings, comments and regular expressions are
    # recognised so that their braces do not count (a `/` after `)` divides unless that `)` closes
    # an if/while/for/with head). A declaration starts where a statement can, outside
    # any bracket: at the start, after `;` or `}`, or after a line break that ends the previous
    # statement (automatic semicolon insertion; not after a control head, where it would be that
    # statement's body). A `\u` escape in its name is decoded; one that does not
    # decode to an ASCII identifier is {JsRuntime::Unsupported}. Inside a declaration anything the scanner cannot follow --
    # an unterminated string, comment, regular expression or body, a template literal -- is
    # {JsRuntime::Unsupported} (Jint may report a syntax error there, this port cannot tell); at
    # the top level the scan just stops, and {JsParser} reports what it finds in the rest.
    # The source is held as an array of characters: String#[] on a non-ASCII UTF-8 string walks
    # it from the start.
    class JsSource
      # A top-level function declaration.
      # @!attribute name [String]
      # @!attribute fingerprint [String] SHA-256 of the normalised declaration text
      # @!attribute line [Integer] 1-based line of the `function` keyword in the program
      Declaration = Struct.new(:name, :fingerprint, :line)

      # The scan stopped at the top level.
      class Stop < StandardError; end
      private_constant :Stop

      LINE_TERMINATORS = JsParser::LINE_TERMINATORS
      BLANK = (JsParser::SPACES.chars + LINE_TERMINATORS).freeze
      IDENT_START = /[A-Za-z_$\\[^\x00-\x7F]]/
      IDENT_PART = /[A-Za-z0-9_$\\[^\x00-\x7F]]/
      # After these a `/` divides; anywhere else it starts a regular expression.
      OPERAND_END = [')', ']'].freeze
      # Keywords after which an expression (so a regular expression) follows.
      EXPRESSION_KEYWORDS = %w[return typeof instanceof in of new delete void throw case do else yield await].freeze
      # Keywords whose parenthesised head a statement follows: after its `)` a `/` starts a regex.
      CONTROL_HEADS = %w[if while for with].freeze
      # A `\u` escape of an identifier: \u{X..} or \uXXXX.
      NAME_ESCAPE = /\\u(?:\{(\h{1,6})\}|(\h{4}))/
      ASCII_NAME = /\A[A-Za-z_$][A-Za-z0-9_$]*\z/
      BRACKETS = { '{' => 1, '(' => 1, '[' => 1, '}' => -1, ')' => -1, ']' => -1 }.freeze

      # @param source [String]
      # @return [Array(Array<Declaration>, String)] the declarations in order, and the program
      #   with them blanked out
      # @raise [JsRuntime::Unsupported] a declaration the scanner cannot follow
      def self.split(source)
        new(source).split
      end

      # @param source [String] a declaration or a whole program
      # @return [String, nil] its fingerprint; nil when the scanner cannot follow it (an
      #   unterminated string, comment or regular expression, a template literal)
      def self.fingerprint(source)
        Digest::SHA256.hexdigest(new(source).normalise)
      rescue Stop
        nil
      end

      def initialize(source)
        @chars = source.to_s.scrub(ConfigFile::REPLACEMENT).chars
        @pos = 0
        @line = 1
        @heads = [] # one entry per open `(`: whether it opened an if/while/for/with head (one scan per object)
      end

      # @return [Array(Array<Declaration>, String)]
      def split
        declarations = []
        rest = @chars.dup
        scan_top_level do |start, name, line|
          finish = declaration_end(start)
          declarations << Declaration.new(name, self.class.fingerprint(@chars[start...finish].join), line)
          blank_out(rest, start, finish)
        end
        [declarations, rest.join]
      end

      # The normalised text of the whole source (see the class comment).
      # @return [String]
      # @raise [Stop] a token the scanner cannot follow
      def normalise
        out = +''
        prev = nil
        loop do
          gap = blank_gap
          break if @pos >= @chars.length

          out << gap unless out.empty?
          start = @pos
          prev = token(prev)
          out << @chars[start...@pos].join
        end
        out
      end

      private

      # --- declarations ----------------------------------------------------------------------

      # Yields (start, name, line) for each top-level declaration; the block leaves @pos after it.
      def scan_top_level
        prev = nil # the previous significant token: [type, text(, :head)]
        depth = 0 # of all brackets: a declaration inside an argument list or array is none
        loop do
          newline = blank_gap == "\n"
          break if @pos >= @chars.length

          if depth.zero? && word_at?('function') && statement_start?(prev, newline) && (name = declaration_name)
            yield @pos, name, @line
            prev = [:punct, '}']
          else
            prev = token(prev)
            depth += BRACKETS.fetch(prev[1], 0) if prev[0] == :punct
          end
        end
      rescue Stop
        nil
      end

      def statement_start?(prev, newline)
        return true if prev.nil? || (prev[0] == :punct && [';', '}'].include?(prev[1]))
        return false unless newline

        %i[ident number string regex].include?(prev[0]) || (prev[0] == :punct && operand_end?(prev))
      end

      # A `)` or `]` that ends an operand (not the `)` of a control head).
      def operand_end?(prev)
        OPERAND_END.include?(prev[1]) && prev[2] != :head
      end

      def word_at?(word)
        @chars[@pos, word.length].join == word && !char(@pos + word.length).match?(IDENT_PART)
      end

      # `function` NAME `(`: the name (the scanner stays before `function`); nil otherwise.
      def declaration_name
        save = [@pos, @line]
        @pos += 'function'.length
        blank_gap
        name = char(@pos).match?(IDENT_START) ? decode_name(read_word) : nil
        blank_gap
        name = nil if name.nil? || JsParser::KEYWORDS.include?(name) || char(@pos) != '('
        name
      rescue Stop
        nil
      ensure
        @pos, @line = save
      end

      # A name with `\u` escapes decoded (Jint binds `function \u0064oPush` as doPush); an escaped
      # keyword then is no name (a syntax error in Jint).
      # @raise [JsRuntime::Unsupported] an escape that does not decode to an ASCII identifier
      def decode_name(word)
        return word unless word.include?('\\')

        name = word.gsub(NAME_ESCAPE) { (code = (Regexp.last_match(1) || Regexp.last_match(2)).hex) < 0x80 ? code.chr : '\\' }
        return name if name.match?(ASCII_NAME)

        unsupported("the escaped name #{word}")
      end

      # The position after the `}` that closes the declaration at +start+: the first `}` back at
      # bracket depth 0 (the parameter list's parentheses return there before the body opens).
      def declaration_end(start)
        @pos = start
        prev = nil
        depth = 0
        loop do
          blank_gap
          unsupported('an unterminated body') if @pos >= @chars.length
          prev = token(prev)
          next unless prev[0] == :punct

          case prev[1]
          when '{', '(', '[' then depth += 1
          when '}', ')', ']'
            depth -= 1
            unsupported('an unbalanced body') if depth.negative?
            return @pos if depth.zero? && prev[1] == '}'
          end
        end
      rescue Stop => e
        unsupported(e.message)
      end

      # Spaces over [start, finish), line terminators kept, one space per UTF-16 unit so the
      # columns JsParser reports stay those of the original program.
      def blank_out(chars, start, finish)
        (start...finish).each do |i|
          chars[i] = chars[i].ord > 0xFFFF ? '  ' : ' ' unless LINE_TERMINATORS.include?(chars[i])
        end
      end

      # --- tokens ----------------------------------------------------------------------------

      def char(index)
        @chars[index].to_s
      end

      # One token at @pos. @return [Array(Symbol, String)]
      # @raise [Stop] a token the scanner cannot follow
      def token(prev)
        first = char(@pos)
        if ['"', "'"].include?(first) then string(first)
        elsif first == '`' then stop('a template literal')
        elsif first.match?(/[0-9]/) || (first == '.' && char(@pos + 1).match?(/[0-9]/)) then number
        elsif first.match?(IDENT_START) then [:ident, read_word]
        elsif first == '/' && regex_allowed?(prev) then regex
        else
          @pos += 1
          punct(first, prev)
        end
      end

      # A punctuator; the `)` closing an if/while/for/with head is marked :head.
      def punct(text, prev)
        case text
        when '(' then @heads.push(prev && CONTROL_HEADS.include?(prev[1])) # only an identifier's text is a bare keyword
        when ')' then return [:punct, text, :head] if @heads.pop
        end
        [:punct, text]
      end

      def regex_allowed?(prev)
        return true if prev.nil?
        return EXPRESSION_KEYWORDS.include?(prev[1]) if prev[0] == :ident
        return !operand_end?(prev) if prev[0] == :punct

        false
      end

      # An identifier, `\u{X..}` escapes included.
      def read_word
        start = @pos
        while @pos < @chars.length && char(@pos).match?(IDENT_PART)
          braced = char(@pos) == '\\' && @chars[@pos + 1, 9].join[/\Au\{\h{1,6}\}/]
          @pos += braced ? braced.length + 1 : 1
        end
        @chars[start...@pos].join
      end

      def number
        start = @pos
        @pos += 1
        while @pos < @chars.length
          current = char(@pos)
          if current.match?(/[0-9A-Za-z_.]/) then @pos += 1
          elsif %w[+ -].include?(current) && char(@pos - 1).match?(/[eE]/) && !@chars[start, 2].join.match?(/0[xX]/) then @pos += 1
          else break
          end
        end
        [:number, @chars[start...@pos].join]
      end

      def string(quote)
        start = @pos
        @pos += 1
        loop do
          current = char(@pos)
          stop('an unterminated string') if current.empty? || ["\n", "\r"].include?(current)
          @pos += 1
          return [:string, @chars[start...@pos].join] if current == quote
          next unless current == '\\'

          escaped = char(@pos)
          @pos += escaped == "\r" && char(@pos + 1) == "\n" ? 2 : 1
          @line += 1 if LINE_TERMINATORS.include?(escaped)
        end
      end

      def regex
        start = @pos
        @pos += 1
        in_class = false
        loop do
          current = char(@pos)
          stop('an unterminated regular expression') if current.empty? || LINE_TERMINATORS.include?(current)
          @pos += 1
          if current == '\\' then @pos += 1
          elsif current == '[' then in_class = true
          elsif current == ']' then in_class = false
          elsif current == '/' && !in_class then break
          end
        end
        @pos += 1 while @pos < @chars.length && char(@pos).match?(IDENT_PART)
        [:regex, @chars[start...@pos].join]
      end

      # --- white space and comments ------------------------------------------------------------

      # Skips white space and comments. @return [String] "" when nothing was skipped, else
      # "\n" if a line terminator was among it, else " "
      def blank_gap
        start = @pos
        newline = false
        while @pos < @chars.length
          if BLANK.include?(@chars[@pos])
            newline = line_break || newline
            @pos += 1
          elsif @chars[@pos, 2].join == '//'
            @pos += 1 until @pos >= @chars.length || LINE_TERMINATORS.include?(@chars[@pos])
          elsif @chars[@pos, 2].join == '/*'
            newline = block_comment || newline
          else
            break
          end
        end
        return '' if @pos == start

        newline ? "\n" : ' '
      end

      # @return [Boolean] whether the comment held a line terminator
      def block_comment
        @pos += 2
        newline = false
        until @chars[@pos, 2].join == '*/'
          stop('an unterminated comment') if @pos >= @chars.length
          newline = line_break || newline
          @pos += 1
        end
        @pos += 2
        newline
      end

      # Whether the character at @pos is a line terminator (counted; CR LF once).
      def line_break
        return false unless LINE_TERMINATORS.include?(@chars[@pos])

        @line += 1 unless @chars[@pos] == "\n" && @pos.positive? && @chars[@pos - 1] == "\r"
        true
      end

      def stop(what)
        raise Stop, what
      end

      def unsupported(what)
        raise JsRuntime::Unsupported, "#{what} in a JavaScript function declaration"
      end
    end
  end
end
