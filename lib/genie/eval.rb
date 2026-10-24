# frozen_string_literal: true

module Lich
  module Genie
    # Boolean/string expression evaluator backing `if`, `while`, `eval`, `waiteval`, eval
    # actions and `#eval`/`#if`: a LITERAL port of Remix Script/Eval.cs. Every method
    # names the C# member it ports; read them side by side.
    #
    # The model is Remix's, not a grammar: ReplaceKeyWords, then Parse cuts the text into a
    # FLAT list of typed sections (separator, number, string, function, negate, "(" and ")"),
    # ParseQueue walks it, and each parenthesized range gets ParseSection's three passes
    # (comparisons, `!`, `&&`/`||`) over the sections not yet consumed. Nothing is ever
    # removed: a consumed section is only flagged parsed, the result is the first non-empty
    # unparsed number/string section (EvalString) or "any unparsed number section is true"
    # (DoEval). So, like Remix: `1x = 1` is "1" (a number then a word), `(3 + 5) = 10` is
    # "3", `0 1` is true, a missing operand leaves the other one standing, a wrong-arity call
    # is a silent no-op that swallows its arguments, an unclosed function paren still calls
    # it, `!"x"` is the STRING "1" (false as a condition), `defined(x)` is the word "defined"
    # (the Functions list lacks its closing `|`, Eval.cs:285 R) and function names are
    # case-sensitive.
    #
    # Instantiate per script (Remix's per-script m_oEval): {#result_list} is ONE array for
    # the evaluator's lifetime, cleared at the start of every evaluation and refilled by a
    # matchre() hit (Eval.cs:48, 877, 1177-1179 R). A caller that keeps a reference to it
    # (the interpreter's `if`/`eval` capture binding) sees every later clear.
    #
    # What .NET throws escapes EvalString/DoEval in Remix (substr/substring out of range,
    # VB ToInteger, element's int.Parse, replace's empty old value, an invalid matchre /
    # replacere pattern): here a {Fault} with the .NET message (an invalid pattern's reason is
    # Onigmo's, not .NET's RegexParseException text); the interpreter reports it and stops the
    # script (decided; Remix stalls the script). `count(x, "")` loops forever in Remix
    # (Eval.cs:1315-1330 R): a {Fault} too (decided, open-items.md K3).
    #
    # matchre()/replacere() compile through {NetRegex}, so their
    # `^`/`$` are Multiline where Eval's Regex.Match uses RegexOptions.None (only differs on
    # a subject holding a newline; open-items.md Q3), and .NET's Unicode \w\d\s are
    # Onigmo's ASCII ones. String positions (len, indexof, lastindexof, substr) count
    # UTF-16 code units like .NET.
    class Eval
      SEPARATORS = '!=<>,&|'

      # Information.IsNumeric(ch) (Eval.cs:205 R): a char that parses as a double alone -- 0-9 and
      # en-US's infinity sign U+221E (a genieoracle scan of the BMP).
      NUMBER_CHAR = /\A[0-9#{Numeric::INFINITY_SIGN}]\z/

      # Eval.cs:285 R, verbatim: no `|` after "defined", so `defined` is never a function.
      FUNCTIONS = '|instr|instring|contains|indexof|lastindexof|match|startswith|endswith|replace|tolower|toupper|trim|len|length|substr|substring|matchre|replacere|count|element|def|defined'

      # ReplaceKeyWordsSection (Eval.cs:94-150 R), keyed by the lowercased match.
      KEYWORDS = { 'eq' => '=', 'and' => '&&', 'or' => '||',
                   'not' => '!', 'true' => '1', 'false' => '0' }.freeze

      # An exception .NET raises inside Eval.cs (it escapes EvalString/DoEval). The message
      # is the .NET one, except "Invalid pattern '<p>': <reason>", whose reason is Onigmo's.
      class Fault < Error; end

      # Sections (Eval.cs:30-41 R): sBlock, BlockType, bParsed.
      Section = Struct.new(:block, :type, :parsed)

      # @param globals [#key?, #include?, nil] the global variable list, for def()
      # @param on_unsupported [#call, nil] told (compiled, "matchre()"/"replacere()") about a
      #   {NetRegex::Unsupported} pattern, so the owner can warn once
      def initialize(globals: nil, on_unsupported: nil)
        @globals = globals
        @on_unsupported = on_unsupported
        @result_list = []
      end

      # m_RegExpResultList (Eval.cs:872, 883-889 R): the groups of the last matchre() hit
      # of the current evaluation; the SAME array object for the evaluator's lifetime.
      # @return [Array<String>]
      attr_reader :result_list

      # DoEval (Eval.cs:874-881 R): `if`, `while`.
      # @param text [String]
      # @return [Boolean]
      # @raise [Fault]
      def do_eval(text)
        @result_list.clear
        boolean_result(Pass.new(self, replace_keywords(net_string(text))).run)
      end

      # EvalString (Eval.cs:45-52 R): `eval`, `waiteval`, eval actions, `#eval`.
      # @param text [String]
      # @return [String]
      # @raise [Fault]
      def eval_string(text)
        @result_list.clear
        string_result(Pass.new(self, replace_keywords(net_string(text))).run)
      end

      # @!visibility private
      # def()/defined() (Eval.cs:1258-1270 R): m_oGlobals.VariableList.ContainsKey.
      def global_defined?(name)
        return false unless @globals
        return @globals.key?(name) if @globals.respond_to?(:key?)
        return @globals.include?(name) if @globals.respond_to?(:include?)

        false
      end

      # @!visibility private
      # {NetRegex.compile}; a .NET-invalid pattern is a {Fault} (Regex.Match throws
      # RegexParseException); an {NetRegex::Unsupported} one is reported to the owner.
      def net_regex(pattern, where)
        compiled = begin
          NetRegex.compile(pattern)
        rescue RegexpError => e
          raise Fault, "Invalid pattern '#{pattern}': #{e.message}"
        end
        @on_unsupported&.call(compiled, where) if compiled.is_a?(NetRegex::Unsupported)
        compiled
      end

      # @!visibility private
      # The matchre() hit (Eval.cs:1177-1179 R): Clear, then every group's value.
      def capture(groups)
        @result_list.clear
        @result_list.concat(groups)
      end

      # IsSectionTrue (Eval.cs:1279-1313 R): "0" false, "1" true (any type), else a number
      # section whose int.Parse is > 0 (`09` is 9; a fraction or an Int32 overflow is false).
      # @param section [Section]
      # @return [Boolean]
      def self.section_true?(section)
        return false if section.block == '0'
        return true if section.block == '1'
        return false unless section.type == :number

        value = Numeric.net_int32(section.block)
        !value.nil? && value.positive?
      end

      private

      # {Text.net_string}: no Ruby string method below raises on invalid UTF-8.
      def net_string(text)
        Text.net_string(text)
      end

      # ReplaceKeyWords (Eval.cs:54-81 R): keywords are replaced outside closed quotes and in
      # the trailing segment, even the body of an unterminated quote (Eval.cs:79 R).
      def replace_keywords(text)
        result = +''
        inside = false
        temp = +''
        text.each_char do |ch|
          temp << ch
          if inside
            next unless ch == '"'

            inside = false
            result << temp
            temp = +''
          elsif ch == '"'
            inside = true
            result << keyword_section(temp)
            temp = +''
          end
        end
        result << keyword_section(temp)
      end

      # ReplaceKeyWordsSection (Eval.cs:92-150 R): `\b(eq|and|or|not|true|false)\b` with
      # IgnoreCase (Remix's `|`; upstream's `&` made it None), the lowercased match mapped.
      # Remix re-matches from the start after each replacement; a replacement never creates a
      # new keyword, so one gsub is the same. Ruby's /i also folds U+017F (long s) to 's',
      # which .NET's IgnoreCase does not; such a match has no KEYWORDS entry and stays.
      def keyword_section(segment)
        segment.gsub(/\b(eq|and|or|not|true|false)\b/i) { |m| KEYWORDS.fetch(m.downcase, m) }
      end

      # GetStringResult (Eval.cs:400-422 R): the unparsed number/string sections in order,
      # each taken while the result is still EMPTY -- so the first non-empty one (`"" x` is
      # "x").
      def string_result(sections)
        result = ''
        sections.each do |s|
          result = s.block if result.empty? && !s.parsed && %i[number string].include?(s.type)
        end
        result
      end

      # GetBooleanResult (Eval.cs:425-455 R): true when ANY unparsed NUMBER section is true.
      def boolean_result(sections)
        sections.any? { |s| !s.parsed && s.type == :number && Eval.section_true?(s) }
      end

      # One evaluation: Parse (Eval.cs:153-283 R) into the section list, then ParseQueue.
      class Pass
        def initialize(owner, text)
          @owner = owner
          @text = text
          @sections = []
        end

        # @return [Array<Section>] the section list after ParseQueue
        def run
          parse
          parse_queue(0)
          @sections
        end

        private

        # Parse (Eval.cs:153-283 R): the character loop, verbatim.
        def parse
          chars = @text.chars
          inside = false
          ignore_number = false
          current = :separator
          sp = 0
          chars.each_with_index do |ch, cp|
            if inside
              inside = false if ch == '"'
            elsif ch == '"'
              if cp > sp
                enqueue(chars[sp...cp].join, current)
                ignore_number = false
                sp = cp
              end
              current = :string
              inside = true
            elsif SEPARATORS.include?(ch)
              unless current == :separator
                if cp > sp
                  enqueue(chars[sp...cp].join, current)
                  ignore_number = false
                  sp = cp
                end
                current = :separator
              end
            elsif !ignore_number && (NUMBER_CHAR.match?(ch) || ch == '.' || ch == '-')
              unless current == :number
                if cp > sp
                  enqueue(chars[sp...cp].join, current)
                  sp = cp
                end
                current = :number
              end
            elsif ch == '(' || ch == ')'
              if cp > sp
                enqueue(chars[sp...cp].join, current)
                ignore_number = false
                sp = cp
              end
              current = ch == '(' ? :section_start : :section_end
            elsif ch == ' ' || ch == "\t"
              if current == :function
                ignore_number = true # for strings without "" that contain numbers
              else
                if cp > sp
                  enqueue(chars[sp...cp].join, current)
                  sp = cp
                end
                current = :separator
              end
            elsif current != :function
              if cp > sp
                enqueue(chars[sp...cp].join, current)
                sp = cp
              end
              current = :function
              ignore_number = true
            end
          end
          enqueue(chars[sp..].join, current) if chars.length > sp
        end

        # SectionEnqueue (Eval.cs:291-371 R).
        def enqueue(raw, type)
          text = raw.gsub(/\A[ \t]+|[ \t]+\z/, '')
          return if text.empty?

          case type
          when :function
            keyword = KEYWORDS[text.downcase]
            if keyword
              type = { '!' => :negate, '1' => :number, '0' => :number }.fetch(keyword, :separator)
              text = keyword
            elsif !FUNCTIONS.include?("|#{text}|") # assume string
              type = :string
            end
          when :separator
            type = :negate if text == '!'
          when :string
            text = text[1...-1] if text.length > 1 && text.start_with?('"') && text.end_with?('"')
          end
          @sections << Section.new(text, type, false)
        end

        # ParseQueue (Eval.cs:374-397 R). An unclosed "(" parses its range to the end AND the
        # enclosing one; a ")" at the top level ends parsing there (the rest stays raw).
        def parse_queue(start)
          last = @sections.length - 1
          j = start
          while j <= last
            case @sections[j].type
            when :section_start then j = parse_queue(j + 1)
            when :section_end
              parse_section(start, j - 1)
              return j
            end
            j += 1
          end
          parse_section(start, @sections.length - 1)
          @sections.length - 1
        end

        # ParseSection (Eval.cs:482-641 R): the function call owning this range, then the
        # comparison, negation and logical passes over its unparsed sections.
        def parse_section(first, last)
          raise Fault, 'Invalid argument to ParseSection()' if last >= @sections.length || first.negative?

          parse_function(first - 2, last) if first >= 2 && @sections[first - 2].type == :function
          compare_pass(first, last)
          negate_pass(first, last)
          logical_pass(first, last)
          # "Single object - Return it" (Eval.cs:636-640 R) re-flags a section that is
          # already unparsed: a no-op.
        end

        def unparsed(first, last)
          (first..last).each do |j|
            section = @sections[j]
            yield section, j unless section.parsed
          end
        end

        # Do all = > < etc. (Eval.cs:499-551 R): && and || reset both sides (#145).
        def compare_pass(first, last)
          left = comparer = -1
          unparsed(first, last) do |section, j|
            case section.type
            when :number, :string
              if left > -1 && comparer > -1
                if compare(left, j, comparer, true)
                  @sections[j].parsed = true
                  @sections[comparer].parsed = true
                  left = -1
                end
                comparer = -1
              else
                left = j
              end
            when :separator
              if %w[&& ||].include?(section.block)
                left = comparer = -1
              else
                comparer = j
              end
            end
          end
        end

        # Do "not" (Eval.cs:553-590 R): the next number/string section becomes "0"/"1",
        # keeping its TYPE (a negated string stays a string).
        def negate_pass(first, last)
          negate = false
          unparsed(first, last) do |section, _j|
            case section.type
            when :negate
              section.parsed = true
              negate = true
            when :number, :string
              next unless negate

              section.block = Eval.section_true?(section) ? '0' : '1'
              negate = false
            end
          end
        end

        # Do "and" and "or" (Eval.cs:592-633 R): the left operand is NOT reset after a fold.
        def logical_pass(first, last)
          left = comparer = -1
          unparsed(first, last) do |section, j|
            case section.type
            when :number, :string
              if left > -1 && comparer > -1
                if compare(left, j, comparer, false)
                  @sections[j].parsed = true
                  @sections[comparer].parsed = true
                end
                comparer = -1
              else
                left = j
              end
            when :separator
              comparer = j
            end
          end
        end

        # ParseCompare (Eval.cs:644-870 R): numeric only when both sections are numbers
        # (Utility.StringToDouble); strings compare ordinally and are never > or <; && and ||
        # of anything but two numbers are 0. The result replaces the LEFT section (a number,
        # unparsed). An operator outside the pass's set answers false.
        def compare(left, right, comparer, skip_and_or)
          lhs = @sections[left]
          rhs = @sections[right]
          numbers = lhs.type == :number && rhs.type == :number
          if numbers
            l = Numeric.string_to_double(lhs.block)
            r = Numeric.string_to_double(rhs.block)
          end
          op = @sections[comparer].block
          result = skip_and_or ? comparison(op, numbers, l, r, lhs, rhs) : logical(op, numbers, l, r)
          return false if result.nil?

          lhs.block = result ? '1' : '0'
          lhs.type = :number
          lhs.parsed = false
          true
        end

        def comparison(op, numbers, l, r, lhs, rhs)
          case op
          when '=', '==' then numbers ? l == r : lhs.block == rhs.block
          when '!=', '<>' then numbers ? l != r : lhs.block != rhs.block
          when '>' then numbers && l > r
          when '>=' then numbers && l >= r
          when '<' then numbers && l < r
          when '<=' then numbers && l <= r
          end
        end

        def logical(op, numbers, l, r)
          case op
          when '||' then numbers && (l > 0 || r > 0)
          when '&&' then numbers && l > 0 && r > 0
          end
        end

        # BuildArgs (Eval.cs:1333-1349 R): every unparsed string/number section of the range,
        # each flagged parsed -- whatever the function then does with them.
        def build_args(first, last)
          args = []
          unparsed(first, last) do |section, _j|
            next unless %i[string number].include?(section.type)

            args << section.block
            section.parsed = true
          end
          args
        end

        # ParseFunction (Eval.cs:892-1277 R): a wrong argument count leaves the function
        # section as it was (a function: never a result) -- its arguments are consumed.
        def parse_function(first, last)
          raise Fault, 'Invalid argument to ParseFunction()' if last >= @sections.length || first.negative?

          args = build_args(first, last)
          result = Functions.call(@owner, @sections[first].block.downcase, args)
          return if result.nil?

          section = @sections[first]
          section.block, section.type = result
          section.parsed = false
        end
      end

      # The ParseFunction switch (Eval.cs:901-1276 R). Each returns [block, type], or nil
      # when Remix leaves the section untouched (wrong arity, substr's 2-argument range).
      module Functions
        module_function

        def call(owner, name, args)
          case name
          when 'instr', 'instring', 'contains' then bool(args, 2) { args[0].include?(args[1]) }
          when 'indexof' then number(args, 2) { utf16_index(args[0], args[0].index(args[1])) + 1 }
          when 'lastindexof' then number(args, 2) { utf16_index(args[0], args[0].rindex(args[1])) + 1 }
          when 'match' then bool(args, 2) { args[0] == args[1] }
          when 'startswith' then bool(args, 2) { args[0].start_with?(args[1]) }
          when 'endswith' then bool(args, 2) { args[0].end_with?(args[1]) }
          when 'replace' then string(args, 3) { replace(*args) }
          when 'tolower' then string(args, 1) { Text.net_downcase(args[0]) }
          when 'toupper' then string(args, 1) { Text.net_upcase(args[0]) }
          when 'trim' then string(args, 1) { Text.net_trim(args[0]) }
          when 'len', 'length' then number(args, 1) { utf16_length(args[0]) }
          when 'substr', 'substring' then substr(args)
          when 'matchre' then matchre(owner, args)
          when 'replacere' then string(args, 3) { replacere(owner, *args) }
          when 'count' then number(args, 2) { count(args[0], args[1]) }
          when 'element' then string(args, 2) { element(args[0], args[1]) }
          when 'def', 'defined' then bool(args, 1) { owner.global_defined?(args[0]) }
          else raise Fault, 'Invalid function name.'
          end
        end

        def bool(args, arity)
          return nil unless args.length == arity

          [yield ? '1' : '0', :number]
        end

        def number(args, arity)
          return nil unless args.length == arity

          [yield.to_s, :number]
        end

        def string(args, arity)
          return nil unless args.length == arity

          [yield, :string]
        end

        # String.Replace(old, new): ordinal, every occurrence; an empty old value throws.
        def replace(text, old, new)
          raise Fault, "The value cannot be an empty string. (Parameter 'oldValue')" if old.empty?

          text.gsub(old) { new }
        end

        # The substr/substring case (Eval.cs:1107-1165 R): VB ToInteger arguments (strict,
        # they throw), C# int arithmetic (wrapping), then String.Substring (which throws).
        def substr(args)
          if args.length == 3
            length_total = utf16_length(args[0])
            start = to_integer(args[1])
            length = to_integer(args[2])
            if length.negative?
              if wrap32(start + length) >= 0
                start = wrap32(start + length)
                raise Fault, 'Negating the minimum value of a twos complement number is invalid.' if length == -(2**31)

                length = length.abs
              else
                start = 0
                length = to_integer(args[1])
              end
            end
            start = 0 if start.negative?
            length = 0 if length.negative?
            return [utf16_substring(args[0], start), :string] if wrap32(start + length) > length_total

            [utf16_substring(args[0], start, length), :string]
          elsif args.length == 2
            start = to_integer(args[1])
            return nil unless start <= utf16_length(args[0]) && start >= 0

            [utf16_substring(args[0], start), :string]
          end
        end

        # VB Conversions.ToInteger(string): the strict port; its exception is a Fault.
        def to_integer(text)
          VbConversions.to_integer(text)
        rescue Fault
          raise
        rescue Error => e
          raise Fault, e.message
        end

        def wrap32(value)
          ((value + (2**31)) % (2**32)) - (2**31)
        end

        # The matchre case (Eval.cs:1167-1193 R): Regex.Match(args[0], args[1]); a hit
        # replaces the result list with every group's value.
        def matchre(owner, args)
          return nil unless args.length == 2

          match = owner.net_regex(args[1], 'matchre()').match(args[0])
          return ['0', :number] unless match

          owner.capture(match.to_a.map(&:to_s))
          ['1', :number]
        end

        # Regex.Replace(args[0], args[1], args[2]) (Eval.cs:1195-1209 R), pattern via
        # {NetRegex}, replacement language via {NetReplace}.
        def replacere(owner, subject, pattern, replacement)
          NetReplace.replace(owner.net_regex(pattern, 'replacere()'), subject, replacement) || subject
        end

        # Count (Eval.cs:1315-1330 R): non-overlapping IndexOf hits. An empty needle never
        # advances, so Remix loops forever; decided: a Fault (the script stops).
        def count(text, match)
          raise Fault, 'count() with an empty search text never returns (Remix loops forever)' if match.empty?

          total = 0
          i = text.index(match)
          while i
            total += 1
            i = text.index(match, i + match.length)
          end
          total
        end

        # The element case (Eval.cs:1227-1256 R): "(" and ")" dropped, split on "|",
        # int.Parse'd index clamped to the list (a negative one counts from the end).
        def element(value, index_text)
          parts = value.delete('()').split('|', -1)
          index = Numeric.net_int32(index_text)
          raise Fault, int_parse_message(index_text) if index.nil?

          index = parts.length - 1 if index >= parts.length
          index += parts.length if index.negative?
          index = 0 if index.negative?
          parts[index].to_s
        end

        # int.Parse's FormatException / OverflowException messages (.NET 8).
        def int_parse_message(text)
          if text.to_s.match?(/\A[\t\n\v\f\r ]*[+-]?[0-9]+[\t\n\v\f\r ]*\0*\z/)
            'Value was either too large or too small for an Int32.'
          else
            "The input string '#{text}' was not in a correct format."
          end
        end

        # .NET String.Length: UTF-16 code units (an astral character counts 2).
        def utf16_length(text)
          return text.length if text.ascii_only? || !text.valid_encoding?

          text.encode(Encoding::UTF_16LE).bytesize / 2
        end

        # A character index (or nil = -1) as a UTF-16 code-unit index.
        def utf16_index(text, index)
          return -1 if index.nil?

          utf16_length(text[0, index])
        end

        # String.Substring(start[, length]) on UTF-16 code units, with .NET's checks. A cut
        # through a surrogate pair yields U+FFFD (what .NET's lone surrogate becomes in UTF-8).
        def utf16_substring(text, start, length = nil)
          total = utf16_length(text)
          raise Fault, "startIndex cannot be larger than length of string. (Parameter 'startIndex')" if start > total
          raise Fault, "Index and length must refer to a location within the string. (Parameter 'length')" if length && start > total - length

          length ||= total - start
          return text[start, length] if text.ascii_only? || !text.valid_encoding?

          units = text.encode(Encoding::UTF_16LE).unpack('v*')[start, length]
          units.pack('v*').force_encoding(Encoding::UTF_16LE)
               .encode(Encoding::UTF_8, invalid: :replace, replace: [0xFFFD].pack('U'))
        end
      end
    end
  end
end
