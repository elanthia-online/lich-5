# frozen_string_literal: true

module Lich
  module Genie
    # .NET Regex.Replace(input, replacement) over a {NetRegex}-compiled pattern: Eval's
    # replacere() (Eval.cs:1195-1209 R) and the display substitutes (`#sub`, Game.cs:3173-3206 R)
    # both use it. The replacement language is .NET's (RegexReplacement): `$$`, `$&`, `` $` ``,
    # `$'`, `$_`, `$+`, `${name}`, `${number}` and `$number` (the maximal digit run); a reference
    # to a group that does not exist, and any other `$`, are copied literally.
    module NetReplace
      module_function

      # Regex.Replace(+subject+, +replacement+) with +regex+ ({NetRegex.compile}'s result).
      # @param regex [Regexp, NetRegex::Emulated, NetRegex::Unsupported]
      # @param subject [String]
      # @param replacement [String, #call] the replacement text, or a callable returning it, called
      #   only once something matched (a display substitute's ParseGlobalVars'd replacement: free
      #   of side effects, so expanding it after the match test is equivalent)
      # @return [String, nil] the new text, nil when nothing matched (Regex.Replace then hands
      #   back the input instance itself, which Game.ParseSubstitutions tests, Game.cs:3185-3187 R)
      def replace(regex, subject, replacement)
        return nil unless regex.match?(subject)

        replacement = replacement.call.to_s if replacement.respond_to?(:call)
        return subject.gsub(regex) { expand(replacement, Regexp.last_match, subject) } if regex.is_a?(Regexp)

        # An {NetRegex::Emulated} pattern is walked match by match like Regex.Replace: its
        # lookbehinds see the text before each match; after an empty match the scan moves on one
        # character.
        out = +''
        last = 0
        pos = 0
        while pos <= subject.length && (match = regex.match(subject, pos))
          out << subject[last...match.begin(0)] << expand(replacement, match, subject)
          last = match.end(0)
          pos = match.end(0) == match.begin(0) ? last + 1 : last
        end
        out << subject[last..].to_s
      end

      # The substitution text for one match.
      # @param replacement [String]
      # @param matchdata [MatchData]
      # @param input [String] the whole input ($_)
      # @return [String]
      def expand(replacement, matchdata, input)
        out = +''
        i = 0
        while i < replacement.length
          if replacement[i] == '$'
            consumed, text = token(replacement, i, matchdata, input)
            out << text
            i += consumed
          else
            out << replacement[i]
            i += 1
          end
        end
        out
      end

      def token(replacement, i, matchdata, input)
        case replacement[i + 1]
        when nil then [1, '$']
        when '$' then [2, '$']
        when '&' then [2, matchdata[0].to_s]
        when '`' then [2, matchdata.pre_match]
        when "'" then [2, matchdata.post_match]
        when '_' then [2, input]
        when '+' then [2, matchdata[matchdata.size - 1].to_s]
        when '{' then braced_group(replacement, i, matchdata)
        when /[0-9]/ then numbered_group(replacement, i, matchdata)
        else [1, '$']
        end
      end

      def braced_group(replacement, i, matchdata)
        close = replacement.index('}', i + 2)
        token = close ? replacement[(i + 2)...close] : nil
        if token&.match?(/\A\d+\z/) && group?(matchdata, token.to_i)
          [close - i + 1, matchdata[token.to_i].to_s]
        elsif token && !token.empty? && !token.match?(/\A\d+\z/) && matchdata.names.include?(token)
          [close - i + 1, matchdata[token].to_s]
        else
          [1, '$']
        end
      end

      def numbered_group(replacement, i, matchdata)
        j = i + 1
        j += 1 while j < replacement.length && replacement[j].match?(/[0-9]/)
        num = replacement[(i + 1)...j].to_i
        group?(matchdata, num) ? [j - i, matchdata[num].to_s] : [1, '$']
      end

      def group?(matchdata, num)
        num >= 0 && num < matchdata.size
      end
    end
  end
end
