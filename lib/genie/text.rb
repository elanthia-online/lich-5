# frozen_string_literal: true

module Lich
  module Genie
    # Small string helpers ported from Genie's Utility.cs, used pervasively by the
    # verb handlers. Faithful to the C# behavior (e.g. argument_string does NOT
    # re-trim its result, matching GetArgumentString).
    module Text
      module_function

      # Port of Utility.GetKeywordString: the first space-delimited word of the
      # .NET-Trim()med row (Utility.cs:957-969 R).
      #
      # @param str [String]
      # @return [String]
      def keyword_string(str)
        s = net_trim(str)
        idx = s.index(' ')
        idx ? s[0...idx] : s
      end

      # Port of Utility.GetArgumentString: everything after the first space of the
      # .NET-Trim()med row, or "" (Utility.cs:971-983 R).
      # Note: the result is intentionally NOT trimmed (matches the C#).
      #
      # @param str [String]
      # @return [String]
      def argument_string(str)
        s = net_trim(str)
        idx = s.index(' ')
        idx ? s[(idx + 1)..] : ''
      end

      # .NET String.ToUpper() / char.ToUpper (en-US, ICU): the SIMPLE per-character case
      # mapping, so the length never changes -- the sharp s (U+00DF) and the fi ligature
      # (U+FB01) stay as they are (Ruby's upcase gives "SS", "FI") and a Greek letter with
      # ypogegrammeni maps to its single-character form (Ruby: two characters; the titlecase
      # is the simple uppercase there).
      # Eval's toupper (Eval.cs:1062 R), MathEval's letter test (MathEval.cs:443 R).
      # @param str [String]
      # @return [String]
      def net_upcase(str)
        s = str.to_s
        return s.upcase if s.ascii_only?
        return s.b.upcase.force_encoding(s.encoding) unless s.valid_encoding?

        s.each_char.map do |c|
          up = c.upcase
          up = c.capitalize if up.length > 1
          up.length > 1 ? c : up
        end.join
      end

      # Simple lowercase per character (String.ToLower, en-US): U+0130 is `i` (Ruby: `i` plus
      # a combining dot). Eval's tolower (Eval.cs:1046 R).
      # @param str [String]
      # @return [String]
      def net_downcase(str)
        s = str.to_s
        return s.downcase if s.ascii_only?
        return s.b.downcase.force_encoding(s.encoding) unless s.valid_encoding?

        s.each_char.map do |c|
          down = c.downcase
          down.length > 1 ? down[0] : down
        end.join
      end

      # The characters .NET String.Trim() removes (char.IsWhiteSpace): the ASCII
      # controls 9-13, space, U+0085, U+00A0, U+1680, U+2000-U+200A, U+2028, U+2029,
      # U+202F, U+205F, U+3000. Unlike Ruby's strip, NUL is NOT trimmed.
      NET_WHITESPACE = [0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0x85, 0xA0, 0x1680, *(0x2000..0x200A),
                        0x2028, 0x2029, 0x202F, 0x205F, 0x3000].pack('U*').freeze
      NET_TRIM = /\A[#{NET_WHITESPACE}]+|[#{NET_WHITESPACE}]+\z/.freeze
      ASCII_TRIM = /\A[\t\n\v\f\r ]+|[\t\n\v\f\r ]+\z/n.freeze

      # Port of .NET String.Trim() (used by Script.TriggerParse, EvalMatch, ...). A string
      # that is not valid UTF-8 is trimmed of the ASCII whitespace only.
      #
      # @param str [String]
      # @return [String]
      def net_trim(str)
        s = str.to_s
        # Fast path: on ASCII text without NUL, Ruby's strip removes exactly .NET's set.
        return s.strip if s.ascii_only? && !s.include?("\0")

        unicode = s.ascii_only? || (s.encoding == Encoding::UTF_8 && s.valid_encoding?)
        return s.gsub(NET_TRIM, '') if unicode

        s.b.gsub(ASCII_TRIM, '').force_encoding(s.encoding)
      end

      # A .NET string never holds invalid UTF-8: the bytes were decoded on the way in, each bad
      # sequence becoming U+FFFD. The evaluators (Eval, MathEval) take their text through this,
      # so no Ruby string method raises on it and the result is the decoded .NET text's. Raw
      # bytes (a BINARY string) are decoded as UTF-8 the same way; ASCII and valid UTF-8 text is
      # returned as it is.
      # @param str [String, nil]
      # @return [String]
      def net_string(str)
        s = str.to_s
        return s if s.ascii_only? || (s.encoding == Encoding::UTF_8 && s.valid_encoding?)

        replacement = [0xFFFD].pack('U')
        return s.dup.force_encoding(Encoding::UTF_8).scrub(replacement) if [Encoding::UTF_8, Encoding::BINARY].include?(s.encoding)

        s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: replacement)
      end

      NET_TRIM_START = /\A[#{NET_WHITESPACE}]+/.freeze

      # Port of .NET String.TrimStart() (char.IsWhiteSpace), e.g. Game.cs's $roomobjs.
      # @param str [String]
      # @return [String]
      def net_trim_start(str)
        s = str.to_s
        return s.sub(/\A[\t\n\v\f\r ]+/, '') if s.ascii_only?
        return s.sub(NET_TRIM_START, '') if s.encoding == Encoding::UTF_8 && s.valid_encoding?

        s.b.sub(/\A[\t\n\v\f\r ]+/n, '').force_encoding(s.encoding)
      end

      NET_TRIM_END = /[#{NET_WHITESPACE}]+\z/.freeze

      # Port of .NET String.TrimEnd() (char.IsWhiteSpace; a NUL is not whitespace), e.g. the
      # label test of Script.AddLine (Script.cs:3856 R).
      # @param str [String]
      # @return [String]
      def net_trim_end(str)
        s = str.to_s
        return s.sub(/[\t\n\v\f\r ]+\z/, '') if s.ascii_only?
        return s.sub(NET_TRIM_END, '') if s.encoding == Encoding::UTF_8 && s.valid_encoding?

        s.b.sub(/[\t\n\v\f\r ]+\z/n, '').force_encoding(s.encoding)
      end

      # Port of Remix Utility.Trim (Utility.cs:847-861 R): CR and LF trimmed from both ends,
      # nothing else -- the line PrintTextToWindow hands to TriggerParse keeps its spaces (e.g.
      # the tester's `{^   Last login}` login trigger).
      # @param str [String]
      # @return [String]
      def trim_crlf(str)
        s = str.to_s
        return s.gsub(CRLF_ENDS, '') if s.valid_encoding?

        s.b.gsub(CRLF_ENDS, '').force_encoding(s.encoding)
      end

      CRLF_ENDS = /\A[\r\n]+|[\r\n]+\z/.freeze

      # Literal port of Remix Utility.SafeSplit (Utility.cs:782-844 R), the split ParseAction
      # uses on an action body (Script.cs:2135 R) and ParseCommand on every command line
      # (Command.cs:235, 244 R). It keeps Remix's quirks: no piece is ever empty and an empty segment is NOT dropped but folds into the
      # next piece (`a;;b` -> `a`, `;b`; `;a` -> `;a`); nothing is trimmed; a `\` escapes
      # only the next `"`, `{`, `}` or separator (both characters stay in the piece) and a
      # `\\` pair cancels itself; inside a `"` string only the closing `"` is special (an
      # escaped quote still closes it); a `}` decrements the depth below zero, so after a
      # stray `}` nothing splits.
      #
      # @param str [String]
      # @param sep [String] one-character separator (Config.cSeparatorChar, default ';')
      # @return [Array<String>]
      def remix_safe_split(str, sep = ';')
        input = str.to_s
        remix_safe_split_ranges(input, sep).map { |range| input[range] }
      end

      # The pieces of {#remix_safe_split} as index ranges into +str+ (the separators between
      # them excluded): {AuthoredCommand} marks the first character of a piece through them.
      # @param str [String]
      # @param sep [String]
      # @return [Array<Range>]
      def remix_safe_split_ranges(str, sep = ';')
        input = str.to_s
        ranges = []
        inside = false
        depth = 0
        escaped = false
        start = 0
        input.each_char.with_index do |ch, cp|
          if inside
            inside = false if ch == '"'
          elsif ch == '"' && !escaped
            inside = true
          elsif ch == '{' && !escaped
            depth += 1
          elsif ch == '}' && !escaped
            depth -= 1
          elsif ch == sep && !escaped && depth.zero? && cp > start
            ranges << (start...cp)
            start = cp + 1
          end
          escaped = ch == '\\' ? !escaped : false
        end
        ranges << (start...input.length) if input.length > start
        ranges
      end

      # Port of Utility.ParseArgs (Utility.cs:390): split a command line into an
      # argument list on ' ' spaces, honoring "..." quoted strings and {...} brace
      # groups so a space inside either is not a split point. This is a FAITHFUL
      # port of the C# algorithm, which is subtler than it looks -- it slices the
      # source with a start pointer rather than accumulating a char buffer, so:
      #
      #   * A `\` escape makes the NEXT char non-special (it won't open a quote/brace
      #     or split) but BOTH the backslash and the escaped char stay in the token
      #     verbatim: `a\ b` -> ["a\ b"], NOT ["a b"].
      #   * Only `"` toggles quoting inside the loop; a backslash inside a quoted run
      #     is a plain char (no escaping there). Interior/unbalanced quotes are KEPT
      #     in the token: `a"b"c` -> ['a"b"c'], `"hello` -> ['"hello'].
      #   * A brace boundary is a TOKEN boundary like a space, even without a space:
      #     `x{y}z` -> ["x", "y", "z"]. Outer braces are stripped, inner kept; `{}`
      #     yields one empty token. A `}` decrements depth even below zero, so a
      #     stray `}` makes later spaces stop splitting (`a}b c` -> ["a}b c"]).
      #   * Wrapping quotes are stripped only if BOTH ends match, and BOTH `"..."`
      #     and '...' are stripped (single quotes only here, not in the loop). A
      #     token that is a lone `"` or `'` makes Genie THROW (its AddArrayItem does
      #     Substring(1, len-2), i.e. length -1) -- we replicate the throw.
      #   * The bTreatUnderscoreAsSpace flag replaces `_`->` ` in every token EXCEPT
      #     the first (Genie gates it on oList.Count > 0).
      #
      # @param str [String]
      # @param treat_underscore_as_space [Boolean]
      # @return [Array<String>]
      # @raise [Error] on a malformed argument string (matches Genie's rethrow)
      def parse_args(str, treat_underscore_as_space: false)
        s = str.to_s
        list = []
        begin
          inside_string = false
          string_char = nil
          bracket_depth = 0
          escape = false
          sp = 0
          cp = 0
          len = s.length
          while cp < len
            ch = s[cp]
            if escape
              escape = false
            elsif inside_string
              inside_string = false if ch == string_char
            elsif ch == '"'
              inside_string = true
              string_char = ch
            elsif ch == '{'
              if bracket_depth.zero?
                l = cp - sp
                add_array_item(list, s[sp, l], treat_underscore_as_space) if l.positive?
                sp = cp
              end
              bracket_depth += 1
            elsif ch == '}'
              bracket_depth -= 1
              if bracket_depth.zero?
                l = cp - sp
                if l.positive?
                  add_array_item(list, s[sp + 1, l - 1], treat_underscore_as_space)
                else
                  add_array_item(list, '')
                end
                sp = cp + 1
              end
            elsif ch == ' '
              if bracket_depth.zero?
                l = cp - sp
                add_array_item(list, s[sp, l], treat_underscore_as_space) if l.positive?
                sp = cp + 1
              end
            elsif ch == '\\'
              escape = true
            end
            cp += 1
          end
          l = len - sp
          add_array_item(list, s[sp, l], treat_underscore_as_space) if l.positive?
        rescue StandardError
          raise Error, "Invalid string in Parse Arguments: #{s}"
        end
        list
      end

      # Port of Utility.AddArrayItem (Utility.cs:494): strip a wrapping "..." then a
      # wrapping '...' (each only when BOTH ends match), optionally replace `_`->` `,
      # and append. The underscore flag is honored only when the list is non-empty
      # (Genie's IIf(oList.Count > 0, flag, false)), so the first token is never
      # underscore-expanded. Faithfully replicates C#'s Substring(1, len-2), which
      # THROWS on a lone-quote token (length -1) -- caught + rethrown by parse_args.
      #
      # @return [void]
      def add_array_item(list, text, treat_underscore_as_space = false)
        text = text.to_s
        text = csharp_substring(text, 1, text.length - 2) if text.start_with?('"') && text.end_with?('"')
        text = csharp_substring(text, 1, text.length - 2) if text.start_with?("'") && text.end_with?("'")
        gate = !list.empty? && treat_underscore_as_space
        text = text.gsub('_', ' ') if gate && text.include?('_')
        list << text
      end

      # Port of Utility.ArrayToString(oList, iStartIndex) (Utility.cs:766-780 R): the items
      # from +start+ on, each followed by a space unless it is blank after Trim, the
      # whole Trim()med -- so `#config key a  b` (ParseArgs: a, b) gives "a b".
      # @param list [Array<String>]
      # @param start [Integer]
      # @return [String]
      def array_to_string(list, start)
        net_trim((list[start..] || []).map { |item| net_trim(item.to_s).empty? ? item.to_s : "#{item} " }.join)
      end

      # Faithful String.Substring(startIndex, length): raises (like C#'s
      # ArgumentOutOfRangeException) on a negative length or an out-of-range slice,
      # instead of Ruby's silent nil/clamp. Only reached with startIndex 1 here, so
      # the trigger is a lone-quote token (length -1).
      #
      # @return [String]
      def csharp_substring(str, start, length)
        raise ArgumentError, 'substring out of range' if length.negative? || start.negative? || (start + length) > str.length

        str[start, length]
      end
    end
  end
end
