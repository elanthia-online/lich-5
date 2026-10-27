# frozen_string_literal: true

module Lich
  module Genie
    # Compiles a script pattern the way Remix does -- `new Regex(pattern, Multiline [| IgnoreCase])`
    # (Script.cs:359-363, 507-511, 3427 R; Globals.cs:951-966 R) and the ValidateRegExp gate
    # `new Regex(s)` (Utility.cs:113-126 R) -- on Ruby's Onigmo engine. Used by
    # matchre, waitforre, action, #trigger and Eval's matchre()/replacere() (Eval.cs:1149,
    # 1176 R: `Regex.Match`/`Regex.Replace`, options None). RegexOptions.Multiline is Ruby's default
    # `^`/`$` behaviour, so no flag is needed for it.
    #
    # Two halves, both driven by what the corpus and the Remix oracle actually show:
    #   * .NET rejects, Onigmo accepts (superset): an unrecognized letter escape
    #     (`\q`, `\h`, `\K`, `\Q`, `\_`, ...; inside a class also `\A \B \G \z \Z \k \8 \9`),
    #     `\x`/`\u` without exactly 2/4 hex digits, `\c` without a control letter, and a
    #     nested quantifier (`a++`, `a?+`, `a**`, `a{2}+`, `a???`, ...). These raise
    #     RegexpError here, like Remix's RegexParseException.
    #   * .NET accepts, Onigmo rejects or reads differently (translated):
    #     - a `-` right after a class shorthand (`\w \W \d \D \s \S \p{..} \P{..}`) inside
    #       `[...]` is a literal hyphen in .NET (`[\w-']`, ScrollSorter.cmd:46) -> `\-`;
    #     - a `[` inside a class is literal in .NET (Ruby nests a class) -> `\[`; `&&` is
    #       literal in .NET (Ruby intersects) -> `&\&`; a leading `]` is literal -> `\]`;
    #     - `{,n}` is literal in .NET (Ruby reads it as {0,n}) -> `\{,n}`;
    #     - `x{n}?` is lazy exactly-n in .NET (Onigmo: optional `(?:x{n})?`) -> `x{n}`;
    #     - a lookbehind Onigmo cannot compile (capture groups inside, or alternatives of
    #       different lengths below the top level: droughtman.cmd:273
    #       `(?<=(field|fluted|full|half) )\bplate\b`) gets its captures made
    #       non-capturing and, if that is not enough, the one alternation group distributed
    #       to the top level (`(?<=field |fluted |full |half )`). One empty `()` per removed
    #       capture follows the lookbehind so later group numbers stay .NET's; that group
    #       captures "" where .NET captures the lookbehind text (recorded divergence). The
    #       lookbehind and its placeholders are one `(?:...)` group so a quantifier after the
    #       lookbehind still applies to it;
    #     - an inline option `(?i)` / `(?-i)` (any of imnsx) mid-branch: .NET scopes it to the
    #       rest of the ENCLOSING group, later alternatives included; Onigmo swallows the
    #       alternation into it. Each becomes a scoped `(?i:` reopened after every `|` of its
    #       group (a tester script's action, {#inline_options}). Letters: s -> Onigmo m, m dropped
    #       (Multiline is always on), n -> {Unsupported};
    #     - a `(?#...)` comment is copied through unparsed;
    #     - a variable-length lookbehind (`(?<!arisen \S+ )zombie`, GenieHunter hunt.cmd:309
    #       through %critters) has no Onigmo form: {Emulated} evaluates it at its fixed distance
    #       from the match start. The distance is counted from the start of the lookbehind's
    #       OWN alternative at each level, so a variable width in an earlier alternative is fine
    #       (`(armored )?warklin|...|(?<!arisen \S+ )zombie`). Where there is no fixed distance
    #       (inside a quantified group, after a variable-width part of its own alternative) or
    #       its body reads differently left to right than .NET's right-to-left lookbehind (an
    #       atomic group, a back-reference, a named group, a conditional) the pattern is
    #       {Unsupported}; so is a back-reference to a capture a rewritten lookbehind lost;
    #     - a conditional on a group name `(?(name)` -> Onigmo's `(?(<name>)`; the expression
    #       form `(?(?=x)..)` / `(?(x)..)`, a name defined later in the pattern, group 0
    #       `(?(0)..)`, balancing groups and numbered names `(?<1>` are {Unsupported};
    #     - option groups read `+`/`-` anywhere, later letters winning (`(?+i)`, `(?i-+s)`).
    #   * Onigmo-only syntax is rejected like .NET: `(?a)` `(?u)` `(?d)` `(?~..)` and any other
    #     unknown `(?x`, invalid group names (also `(?<0>`), relative/level back-references
    #     (`\k<-1>`, `\k<n+0>`), a balancing group naming no group, and `\p{..}`
    #     names other than the Unicode general categories and Is<Block> (`\p{Alpha}`,
    #     `\p{Greek}`, `\p{^L}`). Option letters are case-insensitive (`(?I)`), as in .NET.
    # {#compile} therefore returns a Regexp, an {Emulated} or an {Unsupported} (all answer
    # #match / #match?), memoized per pattern ({CACHE}). It raises for a pattern .NET
    # rejects (also inside an emulated lookbehind); a .NET-valid pattern this module knows
    # Onigmo cannot hold never aborts a script (a decided divergence): an
    # {Unsupported} pattern is registered and never fires, and the caller prints its
    # {Unsupported#warning} once. The constructs below are not recognised, so they can still
    # abort (`\p{IsGreek}`) or match differently.
    # Not covered (no corpus use): class subtraction `[\w-[aeiou]]`,
    # `\p{IsGreek}` block names, the x (pattern whitespace) option, .NET's numbering of
    # unnamed groups before named ones (Onigmo drops unnamed captures once a named group
    # exists), duplicate group names, a `\G` inside an emulated pattern (re-anchored at the
    # candidate start), case-folding that changes a width under IgnoreCase in the {Emulated}
    # distance (non-ASCII only), and .NET's Unicode `\w`/`\d`/`\s` (Onigmo's are ASCII).
    module NetRegex
      # Letter escapes .NET accepts outside a character class (digits and c/x/u/p/P/k are
      # handled separately). Probe: genieoracle matchre("", "x\\<c>") over [A-Za-z0-9_].
      OUTSIDE_LETTERS = 'abdefnrstvwzABDGSWZ'
      # Letter escapes .NET accepts inside a character class (same probe on "[\\<c>]").
      INSIDE_LETTERS = 'abdefnrstvwDSW'
      CLASS_SHORTHAND = /\A\\[wWdDsSpP]/.freeze
      # A .NET quantifier brace: {n}, {n,}, {n,m}; anything else starting with '{' is literal.
      NET_BRACE_QUANTIFIER = /\A\{\d+(?:,\d*)?\}/.freeze
      # A brace Onigmo reads as a quantifier but .NET as literal text.
      RUBY_ONLY_BRACE = /\A\{,\d+\}/.freeze
      # An inline option group `(?imnsx-imnsx)` and a scoped one `(?imnsx-imnsx:`. .NET's
      # ScanOptions reads letters, `-` (switch off from here) and `+` (switch on) in any order
      # and number (`(?+i)`, `(?--i)`, `(?i-+s)`, `(?+)`), but rejects `(?)`; the letters are
      # case-insensitive (`(?I)` is IgnoreCase). genieoracle rxmatch / rx oracle.
      INLINE_OPTIONS = /\A\(\?[imnsx+\-]+\)/i.freeze
      SCOPED_OPTIONS = /\A\(\?[imnsx+\-]+:/i.freeze
      # A named group opener `(?<spec>` / `(?'spec'` (spec checked by {#open_named}).
      NAMED_GROUP = /\A\(\?(?:<(?![=!])([^>]*)>|'([^']*)')/.freeze
      # A .NET group name or number (`(?<1a>` and `(?<a b>` are .NET errors).
      NET_GROUP_NAME = /\A(?:\d+|[[:alpha:]_][[:word:]]*)\z/.freeze
      # The Unicode general categories, the only \p{..} names .NET knows besides Is<Block>
      # (RegexCharClass). genieoracle rxmatch: \p{Alpha} \p{Word} \p{Greek} \p{^L} \p{LC} \p{lu}
      # -> RegexParseException; Onigmo accepts all of them.
      NET_CATEGORIES = %w[C Cc Cf Cn Co Cs L Ll Lm Lo Lt Lu M Mc Me Mn N Nd Nl No
                          P Pc Pd Pe Pf Pi Po Ps S Sc Sk Sm So Z Zl Zp Zs].freeze
      # The deepest group nesting handed to Onigmo. Onigmo parses and compiles each level with
      # one more C-stack frame: on a script thread about 1,500 levels raise SystemStackError,
      # and a second overflow on the same thread kills the whole process (SIGILL), so it cannot
      # be rescued the way Eval's Ruby recursion is. .NET takes any depth (200,000 levels
      # compile and match), so a deeper pattern is {Unsupported} (a decided divergence). The
      # corpus nests 6 deep at most (uber.cmd).
      MAX_GROUP_DEPTH = 256
      TOO_DEEP = "groups nested more than #{MAX_GROUP_DEPTH} deep".freeze

      module_function

      # @param pattern [String] the pattern with any `/.../i` delimiters already removed
      # @param ignore_case [Boolean]
      # @return [Regexp, Emulated, Unsupported] each answers #match (MatchData, .NET group
      #   numbers) and #match?
      # @raise [RegexpError] when .NET rejects the pattern or Onigmo cannot compile its
      #   translation (an uncovered construct, see the module doc)
      #
      # Compiled once per pattern and ignore_case ({CACHE}; matchre validates then compiles,
      # #trigger checks three times, an action re-registered in a loop recompiles): the
      # returned object is shared and immutable to callers.
      def compile(pattern, ignore_case: false)
        CACHE.fetch("#{ignore_case ? 'i' : '-'}#{pattern}") { compile_uncached(pattern.to_s, ignore_case) }
      end

      # {#compile} without the cache.
      def compile_uncached(pattern, ignore_case)
        groups = group_inventory(pattern)
        return Unsupported.new(pattern, TOO_DEEP) if groups.depth > MAX_GROUP_DEPTH

        notes = Notes.new([], [], [], groups)
        text = scan(pattern, notes)
        options = ignore_case ? Regexp::IGNORECASE : nil
        compiled = begin
          Regexp.new(text, options)
        rescue RegexpError => e
          raise if notes.lookbehinds.empty?
          # Is it only the lookbehinds Onigmo cannot hold? With each one read as a lookahead
          # every other restriction still applies (an undefined back-reference inside one
          # raises here, as .NET's parser does).
          raise e unless onigmo_ok?(as_lookaheads(text))

          Emulated.build(text, notes.lookbehinds, options) # raises RegexpError when the rest is invalid too
        end
        reason = notes.unsupported.first || (compiled.reason if compiled.is_a?(Emulated)) ||
                 placeholder_reference(text, notes.placeholders)
        reason ? Unsupported.new(pattern, reason) : compiled
      end

      # A bounded, thread-safe LRU memo of {#compile}: the result, or the RegexpError to
      # raise again (a new one each time, same class and message). Full, it drops the least
      # recently used entry -- script patterns built from changing variables must not grow it
      # without end, and one big script's static patterns must not evict each other (uber.cmd
      # alone registers ~4700, each under up to two keys). A Hash
      # keeps insertion order, so a hit re-inserts its key at the young end.
      class Cache
        def initialize(limit)
          @limit = limit
          @entries = {}
          @lock = Mutex.new
        end

        # @return [Integer] entries held (never more than the limit)
        def size
          @lock.synchronize { @entries.size }
        end

        def fetch(key)
          entry = @lock.synchronize do
            hit = @entries.delete(key)
            @entries[key] = hit if hit
            hit
          end
          unless entry
            entry = begin
              [:ok, yield]
            rescue RegexpError => e
              [:error, e.class, e.message]
            end
            @lock.synchronize do
              @entries.delete(key)
              @entries.delete(@entries.first.first) while @entries.size >= @limit
              @entries[key] = entry
            end
          end
          raise entry[1], entry[2] if entry.first == :error

          entry[1]
        end
      end
      CACHE_LIMIT = 16_384
      CACHE = Cache.new(CACHE_LIMIT)

      # Utility.ValidateRegExp (Utility.cs:113-126 R): true when the pattern compiles.
      # @param pattern [String]
      # @return [Boolean]
      def valid?(pattern)
        compile(pattern)
        true
      rescue StandardError # catch (Exception), like ValidateRegExp; invalid bytes raise too
        false
      end

      # Rewrite a .NET pattern into Onigmo syntax with the same meaning (see the module doc).
      # @param pattern [String]
      # @return [String]
      # @raise [RegexpError] for a construct .NET rejects
      def translate(pattern)
        scan(pattern.to_s, Notes.new([], [], [], group_inventory(pattern.to_s)))
      end

      # What {#scan} found besides the text: +lookbehinds+ = every lookbehind Onigmo cannot
      # compile even after {#rewrite_lookbehind} (variable-length), as {Lookbehind}s whose
      # start/span is their place in the returned text ({Emulated} evaluates them);
      # +unsupported+ = names of .NET constructs the translation drops ({Unsupported});
      # +placeholders+ = index in the returned text of each `()` standing in for a capture a
      # rewritten lookbehind lost; +groups+ = the pattern's {Groups} (from {#group_inventory}).
      Notes = Struct.new(:lookbehinds, :unsupported, :placeholders, :groups)
      # Group names and the number of capturing groups of the whole pattern: .NET resolves
      # a balancing group's or a conditional's name against all of them, later ones too.
      # +opened+ = the names {#open_named} has translated so far (a conditional on a name
      # opened later has no Onigmo form); +depth+ = the deepest group nesting ({MAX_GROUP_DEPTH}).
      Groups = Struct.new(:names, :captures, :opened, :depth)
      Lookbehind = Struct.new(:start, :span, :negative, :body, :icase)

      # The translator (see {#translate}); +notes+ collects what {#compile} needs.
      def scan(s, notes)
        out = +''
        levels = [Level.new(0, {}, nil)]
        i = 0
        last = :none # :none (nothing quantifiable), :atom, :quant, :lazy
        while i < s.length
          c = s[i]
          case c
          when '\\'
            text, i = read_escape(s, i, in_class: false)
            out << text
            last = :atom
          when '['
            text, i = read_class(s, i)
            out << text
            last = :atom
          when '('
            i, last = open_group(s, i, out, levels, notes)
          when ')'
            close_level(out, levels.pop) if levels.length > 1
            out << c
            i += 1
            last = :atom
          when '|'
            reopen_level(out, levels.last)
            i += 1
            last = :none
          when '*', '+', '?'
            if c == '?' && last == :quant
              last = :lazy
            elsif %i[quant lazy].include?(last)
              raise RegexpError, "Nested quantifier '#{c}'"
            else
              last = :quant
            end
            out << c
            i += 1
          when '{'
            if (brace = s[i..][NET_BRACE_QUANTIFIER])
              raise RegexpError, "Nested quantifier '{'" if %i[quant lazy].include?(last)

              out << brace
              i += brace.length
              last = :quant
              if s[i] == '?' && !brace.include?(',')
                # .NET `{n}?` = lazy exactly-n, i.e. still n; Onigmo reads it as `(?:x{n})?`.
                i += 1
                last = :lazy
              end
            else
              out << (s[i..].match?(RUBY_ONLY_BRACE) ? '\\{' : c)
              i += 1
              last = :atom
            end
          else
            out << c
            i += 1
            last = :atom
          end
        end
        levels.reverse_each { |level| close_level(out, level) }
        out
      end

      # One nesting level of the pattern (the top, or a group): how many option scopes
      # {#inline_options} opened in it, the option changes made in it so far (letter =>
      # on/off, carried into every later alternative of the level, like .NET), and the
      # ignore-case state in effect (nil = the compile option).
      Level = Struct.new(:scopes, :changes, :icase)

      # A '(' at s[i]: lookbehind, inline options, comment or a group.
      # @return [[Integer, Symbol]] next index, quantifier state
      def open_group(s, i, out, levels, notes)
        if (head = s[i, 4]) == '(?<=' || head == '(?<!'
          close = group_close(s, i)
          if close
            body = scan(s[(i + 4)...close], Notes.new([], notes.unsupported, [], notes.groups))
            text, placeholders = rewrite_lookbehind(head, body)
            # With placeholders the pair is one group, so a quantifier after the lookbehind
            # (`(?<=(a|bb))?`) still applies to the lookbehind, not to the last placeholder.
            wrap = !placeholders.empty?
            out << '(?:' if wrap
            unless onigmo_ok?(text)
              notes.lookbehinds << Lookbehind.new(out.length, text.length, head == '(?<!', text[4...-1], levels.last.icase)
            end
            out << text
            (placeholders.length / 2).times { |k| notes.placeholders << (out.length + (2 * k)) }
            out << placeholders
            out << ')' if wrap
            return [close + 1, :atom]
          end
        end
        if s[i, 3] == '(?#' # .NET comment: up to the first ')', no nesting
          close = s.index(')', i)
          raise RegexpError, 'Unterminated (?#...) comment' if close.nil?

          out << s[i..close]
          return [close + 1, :none]
        end
        if (options = s[i..][INLINE_OPTIONS])
          inline_options(options, out, levels.last, notes)
          return [i + options.length, :none]
        end

        level = Level.new(0, {}, levels.last.icase)
        if (scoped = s[i..][SCOPED_OPTIONS])
          on, off = option_letters(scoped)
          level.icase = true if on.include?('i')
          level.icase = false if off.include?('i')
          out << "(?#{onigmo_letters(on, off, notes)}:"
          i += scoped.length
        elsif s[i + 1] != '?'
          out << '('
          i += 1
        elsif ':=!>'.include?(s[i + 2].to_s) && !s[i + 2].nil?
          out << s[i, 3]
          i += 3
        elsif s[i + 2] == '('
          i = open_conditional(s, i, out, notes)
        elsif (named = s[i..][NAMED_GROUP])
          out << open_named(named[3...-1], notes)
          i += named.length
        else
          # .NET knows no other `(?x`: Onigmo's (?a) (?u) (?d) (?~...) and a malformed
          # option group (`(?ia)`, `(?)`) are RegexParseException (genieoracle rxmatch).
          raise RegexpError, "Unrecognized grouping construct (?#{s[i + 2]}"
        end
        levels << level
        [i, :none]
      end

      # `(?<name>` / `(?'name'`, the balancing `(?<name-other>` / `(?<-other>`. A name is a
      # number or a word (`(?<a b>`, `(?<1a>`, `(?<x->` are .NET errors); a balancing group's
      # +other+ must name a group of the pattern (.NET error otherwise). Balancing groups and
      # numbered names are .NET-valid but not translated: {Unsupported} (the opener becomes
      # one Onigmo accepts so the rest is still checked). @return [String] the Onigmo opener
      def open_named(spec, notes)
        name, other = spec.split('-', 2)
        valid = (name.empty? ? !other.nil? : name.match?(NET_GROUP_NAME)) &&
                (other.nil? || other.match?(NET_GROUP_NAME))
        raise RegexpError, "Invalid group name (?<#{spec}>" unless valid

        if other
          raise RegexpError, "Reference to undefined group (?<#{spec}>" unless group_defined?(other, notes.groups)

          notes.unsupported << 'a balancing group'
          return name.empty? ? '(?:' : open_named(name, Notes.new([], [], [], notes.groups))
        end
        if name.match?(/\A\d+\z/)
          # Group 0 is the whole match: .NET rejects it as a name, `(?<-0>` is fine (rx oracle).
          raise RegexpError, "Capture group number must be greater than 0 (?<#{spec}>" if name.to_i.zero?

          notes.unsupported << 'a numbered group name'
          return '('
        end
        notes.groups.opened << name
        "(?<#{name}>"
      end

      # `(?(cond)yes|no)`. A number stays (Onigmo reads it the same; an undefined one is an
      # error in both); a group name becomes Onigmo's `(?(<name>)`; anything else is .NET's
      # expression form (a lookahead), which Onigmo lacks: {Unsupported}, the condition is
      # dropped and the branches stay a `(?:` group so the rest is still checked. .NET errors
      # are raised: more than one `|`, a comment, a capture or a malformed number as condition.
      # @return [Integer] index after the condition
      def open_conditional(s, i, out, notes)
        cond_close = group_close(s, i + 2)
        close = group_close(s, i)
        raise RegexpError, 'Not enough )s' if cond_close.nil? || close.nil?

        cond = s[(i + 3)...cond_close]
        raise RegexpError, 'Too many | in (?()|)' if top_level_split(s[(cond_close + 1)...close]).length > 2

        if cond.match?(/\A0+\z/)
          # .NET: group 0 has never matched inside the pattern, so the no-branch always runs;
          # Onigmo rejects the reference (rx oracle).
          notes.unsupported << 'a conditional on group 0'
          out << '(?:'
        elsif cond.match?(/\A\d+\z/)
          out << "(?(#{cond})"
        elsif notes.groups.opened.include?(cond)
          out << "(?(<#{cond}>)"
        elsif notes.groups.names.include?(cond)
          # .NET tests a group defined further on (`(?(n)a|b)(?<n>c)` matches "bc"); Onigmo
          # rejects the forward reference.
          notes.unsupported << 'a conditional on a group defined later'
          out << '(?:'
        else
          raise RegexpError, 'Invalid alternation condition' if cond.match?(/\A(?:\d|\?#|\?<(?![=!])|\?')/)

          scan("(#{cond})", Notes.new([], [], [], notes.groups)) # a .NET error inside it still raises
          notes.unsupported << 'a conditional on an expression'
          out << '(?:'
        end
        cond_close + 1
      end

      def group_defined?(name, groups)
        name.match?(/\A\d+\z/) ? name.to_i <= groups.captures : groups.names.include?(name)
      end

      # {Groups} of the raw .NET +pattern+ (escapes, classes and comments skipped).
      def group_inventory(pattern)
        names = []
        count = 0
        depth = deepest = 0
        j = 0
        while j < pattern.length
          case pattern[j]
          when '\\' then j += 1
          when '[' then j = class_end(pattern, j) - 1
          when ')' then depth -= 1 if depth.positive?
          when '('
            deepest = [deepest, depth += 1].max unless pattern[j, 3] == '(?#'
            if pattern[j + 1] != '?'
              count += 1
            elsif pattern[j, 3] == '(?#'
              j = pattern.index(')', j) || pattern.length
            elsif (named = pattern[j..][NAMED_GROUP])
              name = named[3...-1].split('-', 2).first
              names << name unless name.empty?
              count += 1 unless name.empty?
            end
          end
          j += 1
        end
        Groups.new(names, count, [], deepest)
      end

      # @param pattern [String]
      # @return [Boolean] true when the pattern nests groups deeper than {MAX_GROUP_DEPTH}
      def too_deep?(pattern)
        group_inventory(pattern.to_s).depth > MAX_GROUP_DEPTH
      end

      # `(?imnsx-imnsx)`. .NET applies it from here to the end of the ENCLOSING group, every
      # later alternative of that group included (`^a(?i)b|^c` matches "C"); Onigmo applies it
      # to the rest of the group but swallows the alternation into it (`a(?i:b|^c)`). So each
      # one becomes a scoped `(?flags:` that {#reopen_level} closes and reopens at every `|`
      # of the level and {#close_level} closes at the level's end (non-capturing: group
      # numbers are unchanged). Probes p21/p32 (genieflow Remix), flow t112/t113.
      def inline_options(options, out, level, notes)
        on, off = option_letters(options)
        on.each_char { |letter| level.changes[letter] = true }
        off.each_char { |letter| level.changes[letter] = false }
        level.icase = true if on.include?('i')
        level.icase = false if off.include?('i')
        out << "(?#{onigmo_letters(on, off, notes)}:"
        level.scopes += 1
      end

      def close_level(out, level)
        out << (')' * level.scopes)
        level.scopes = 0
      end

      def reopen_level(out, level)
        close_level(out, level)
        out << '|'
        return if level.changes.empty?

        on = level.changes.select { |_letter, state| state }.keys.join
        off = level.changes.reject { |_letter, state| state }.keys.join
        out << "(?#{onigmo_letters(on, off, Notes.new([], []))}:" # letters noted when first seen
        level.scopes = 1
      end

      # The letters switched on and off by an option group, read left to right like .NET's
      # ScanOptions: `-` / `+` set the mode for the letters after them, a later letter wins
      # (`(?i-i+)` leaves i off, `(?-i+i)` on). @return [Array(String, String)]
      def option_letters(text)
        state = {}
        on = true
        text[2..].downcase.delete(':)').each_char do |c|
          case c
          when '-' then on = false
          when '+' then on = true
          else state[c] = on
          end
        end
        [state.select { |_c, v| v }.keys.join, state.reject { |_c, v| v }.keys.join]
      end

      # .NET option letters as Onigmo's: i and x are the same; s (Singleline, `.` matches
      # "\n") is Onigmo's m; m (Multiline) is dropped -- Remix always sets RegexOptions.
      # Multiline, which is Onigmo's only `^`/`$` mode; n (ExplicitCapture) changes group
      # numbering, which is not translated: dropped and noted (the pattern never fires).
      def onigmo_letters(on, off, notes)
        notes.unsupported << 'the explicit-capture option n' if "#{on}#{off}".include?('n')
        map = ->(letters) { letters.tr('s', 'M').delete('mn').tr('M', 'm') }
        off = map.call(off)
        off.empty? ? map.call(on) : "#{map.call(on)}-#{off}"
      end

      # One escape at s[i] == '\\'. @return [[String, Integer]] Onigmo text, next index
      def read_escape(s, i, in_class:)
        n = s[i + 1]
        return ['\\', i + 1] if n.nil? # trailing backslash: both engines reject it at compile
        return [s[i, 2], i + 2] unless n.match?(/\w/) # \- \. \' ...: literal in both

        case n
        when 'c'
          ctl = s[i + 2]
          raise RegexpError, 'Unrecognized control character' unless ctl&.match?(/[A-Za-z@\[\\\]^_]/)

          [s[i, 3], i + 3]
        when 'x' then fixed_hex(s, i, 2)
        when 'u' then fixed_hex(s, i, 4)
        when 'p', 'P'
          close = s[i + 2] == '{' ? s.index('}', i + 3) : nil
          raise RegexpError, 'Incomplete \\p{X} character escape' if close.nil?

          name = s[(i + 3)...close]
          # Is<Block> names are passed on (Onigmo rejects most).
          raise RegexpError, "Unknown property '#{name}'" unless NET_CATEGORIES.include?(name) || name.start_with?('Is')

          [s[i..close], close + 1]
        when 'k'
          raise RegexpError, 'Unrecognized escape sequence \\k' if in_class || !%w[< '].include?(s[i + 2])

          # The name is a .NET group name or number; Onigmo's relative `\k<-1>` and level
          # `\k<n+0>` forms are .NET errors. Onigmo checks the reference.
          close = s.index(s[i + 2] == '<' ? '>' : "'", i + 3)
          raise RegexpError, 'Malformed \\k<...> named back reference' unless close && s[(i + 3)...close].match?(NET_GROUP_NAME)

          [s[i..close], close + 1]
        when /\d/
          raise RegexpError, "Unrecognized escape sequence \\#{n}" if in_class && %w[8 9].include?(n)

          [s[i, 2], i + 2]
        else
          letters = in_class ? INSIDE_LETTERS : OUTSIDE_LETTERS
          raise RegexpError, "Unrecognized escape sequence \\#{n}" unless letters.include?(n)

          [s[i, 2], i + 2]
        end
      end

      def fixed_hex(s, i, digits)
        hex = s[i + 2, digits].to_s
        raise RegexpError, 'Insufficient hex digits' unless hex.length == digits && hex.match?(/\A\h+\z/)

        [s[i, digits + 2], i + digits + 2]
      end

      # A character class at s[i] == '['. @return [[String, Integer]] Onigmo text, next index
      def read_class(s, i)
        out = +'['
        j = i + 1
        if s[j] == '^'
          out << '^'
          j += 1
        end
        if s[j] == ']' # a leading ']' is a literal in .NET
          out << '\\]'
          j += 1
        end
        prev_shorthand = false
        while j < s.length
          c = s[j]
          return [out << ']', j + 1] if c == ']'

          if c == '\\'
            text, j = read_escape(s, j, in_class: true)
            out << text
            prev_shorthand = text.match?(CLASS_SHORTHAND)
            next
          end

          if c == '-' && s[j + 1] == '[' # .NET subtraction: not translated (no corpus use)
            nested, j = read_class(s, j + 1)
            out << '-' << nested
          elsif c == '-' && prev_shorthand && s[j + 1] != ']'
            out << '\\-'
            j += 1
          elsif c == '['
            out << '\\['
            j += 1
          elsif c == '&' && s[j + 1] == '&'
            out << '&\\&'
            j += 2
          else
            out << c
            j += 1
          end
          prev_shorthand = false
        end
        [out, j] # unterminated: Onigmo reports it at compile
      end

      # Index of the ')' closing the group opened at s[open]; nil when unbalanced.
      def group_close(s, open)
        depth = 0
        j = open
        while j < s.length
          case s[j]
          when '\\' then j += 1
          when '[' then j = class_end(s, j) - 1
          when '(' then depth += 1
          when ')'
            depth -= 1
            return j if depth.zero?
          end
          j += 1
        end
        nil
      end

      # Index just past the class opened at s[open]. Works on raw .NET text and on
      # translated text alike: a '[' inside a class opens a nested one only right after
      # a subtraction '-' (anywhere else it is a .NET literal, escaped once translated).
      def class_end(s, open)
        j = open + 1
        j += 1 if s[j] == '^'
        j += 1 if s[j] == ']'
        while j < s.length
          case s[j]
          when '\\' then j += 1
          when '[' then j = class_end(s, j) - 1 if s[j - 1] == '-'
          when ']' then return j + 1
          end
          j += 1
        end
        s.length
      end

      def onigmo_ok?(text)
        Regexp.new(text)
        true
      rescue RegexpError
        false
      end

      # `(?<=body)` / `(?<!body)` with an Onigmo-compatible body (module doc). +body+ is
      # already translated. @return [Array(String, String)] the lookbehind, then one `()`
      # placeholder per capture it lost
      def rewrite_lookbehind(open, body)
        return ["#{open}#{body})", ''] if onigmo_ok?("#{open}#{body})")

        flat, captures = uncapture(body)
        flat = distribute(flat) || flat unless onigmo_ok?("#{open}#{flat})")
        ["#{open}#{flat})", '()' * captures]
      end

      # Turn every plain capturing '(' in +body+ into '(?:'. @return [[String, Integer]]
      def uncapture(body)
        out = +''
        count = 0
        j = 0
        while j < body.length
          c = body[j]
          if c == '\\'
            out << body[j, 2]
            j += 2
          elsif c == '['
            stop = class_end(body, j)
            out << body[j...stop]
            j = stop
          elsif c == '(' && body[j + 1] != '?'
            out << '(?:'
            count += 1
            j += 1
          else
            out << c
            j += 1
          end
        end
        [out, count]
      end

      # prefix(?:a|b)suffix -> prefix a suffix|prefix b suffix, when the body has no
      # top-level '|' and exactly one unquantified top-level group holding alternatives.
      # @return [String, nil]
      def distribute(body)
        return nil if top_level_split(body).length > 1

        groups = top_level_groups(body).select do |open, close|
          plain = body[open + 1] != '?' || body[open, 3] == '(?:' # never a lookaround/atomic/named/option group
          plain && !body[close + 1].to_s.match?(/[*+?{]/) && top_level_split(group_inner(body, open, close)).length > 1
        end
        return nil unless groups.length == 1

        open, close = groups.first
        prefix = body[0...open]
        suffix = body[(close + 1)..]
        top_level_split(group_inner(body, open, close)).map { |alt| "#{prefix}#{alt}#{suffix}" }.join('|')
      end

      def group_inner(body, open, close)
        start = body[open, 3] == '(?:' ? open + 3 : open + 1
        body[start...close]
      end

      # [open, close] index pairs of the groups at depth 0 of +text+.
      def top_level_groups(text)
        pairs = []
        j = 0
        while j < text.length
          case text[j]
          when '\\' then j += 1
          when '[' then j = class_end(text, j) - 1
          when '('
            close = group_close(text, j)
            return pairs if close.nil?

            pairs << [j, close]
            j = close
          end
          j += 1
        end
        pairs
      end

      # +text+ split on its depth-0 '|'.
      def top_level_split(text)
        parts = []
        depth = 0
        start = 0
        j = 0
        while j < text.length
          case text[j]
          when '\\' then j += 1
          when '[' then j = class_end(text, j) - 1
          when '(' then depth += 1
          when ')' then depth -= 1
          when '|'
            if depth.zero?
              parts << text[start...j]
              start = j + 1
            end
          end
          j += 1
        end
        parts << text[start..]
      end

      # --- variable-length lookbehind (Onigmo has none) -----------------------------

      # Distance in characters from the match start to +target+ (an index into the
      # translated +text+) on EVERY path through the pattern, or a String naming why there
      # is no single distance: an enclosing group is quantified (the spot is visited at
      # several places), or something before it ON ITS OWN PATH has a variable width. Each
      # '|' starts the count over, so a variable width in an earlier alternative does not
      # matter (`(armored )?warklin|...|(?<!arisen \S+ )zombie`, hunt.cmd:309);
      # width nil = unknown so far, an error only once the target is reached.
      # @return [Integer, String]
      def fixed_offset(text, target, from = 0, to = text.length)
        width = 0
        j = from
        while j < target
          if text[j] == '|'
            width = 0
            j += 1
            next
          end
          if text[j] == '(' && (close = group_close(text, j)) && close > target && close < to
            return 'inside a quantified group' if quantifier_width(text, close + 1, 1).first != 1

            head = group_head(text, j)
            return 'inside an unsupported group construct' if head.nil?
            return VARIABLE_BEFORE if width.nil?

            inner = fixed_offset(text, target, j + head, close)
            return inner if inner.is_a?(String)

            return width + inner
          end
          element, j = element_width(text, j)
          width = element && width ? width + element : nil
        end
        width || VARIABLE_BEFORE
      end

      VARIABLE_BEFORE = 'after a variable-width part of the pattern'

      # Whether the spot +target+ of +text+ sits inside an odd number of negative lookarounds:
      # there a lookbehind that holds makes the whole pattern match LESS, so {Emulated}'s
      # candidate search must assume it fails (`(?!(?<=b\w+)z)z`).
      def negated?(text, target)
        enclosing_heads(text, target).count { |head| head.start_with?('(?!', '(?<!') }.odd?
      end

      # Whether a lookbehind at +target+ can make the pattern match LESS by holding, whatever
      # the negation depth: inside an atomic group or a positive lookahead (both commit to the
      # first way they succeed, so a lookbehind that holds can pick a branch -- or captures --
      # that fail later), or anywhere in a pattern with a conditional (its truth can select
      # the other branch). A negative lookahead keeps no captures: {#negated?} covers it.
      # {Emulated} then tries every start instead of a relaxed candidate search.
      def non_monotone?(text, target)
        conditional?(text) || enclosing_heads(text, target).any? { |head| head.start_with?('(?>', '(?=') }
      end

      # Whether +text+ opens a conditional `(?(` -- parsed, so an escaped `\(?(x)` or a
      # class `[(?(]` is not one.
      def conditional?(text)
        j = 0
        while j < text.length
          case text[j]
          when '\\' then j += 1
          when '[' then j = class_end(text, j) - 1
          when '(' then return true if text[j, 3] == '(?('
          end
          j += 1
        end
        false
      end

      # Whether an emulated lookbehind +body+ (translated) looks at text after its own end:
      # a lookahead, `$`, `\z`, `\Z`, `\b`, `\B` or `\G`. Such a body must see the whole
      # line; any other is decided on the text before its spot alone ({Emulated}).
      def looks_right?(body)
        j = 0
        while j < body.length
          case body[j]
          when '\\'
            return true if body[j + 1] && 'zZbBG'.include?(body[j + 1])

            j += 1
          when '[' then j = class_end(body, j) - 1
          when '$' then return true
          when '(' then return true if body[j, 3] == '(?=' || body[j, 3] == '(?!'
          end
          j += 1
        end
        false
      end

      # The openers (first four characters) of the groups enclosing +target+, outermost first.
      def enclosing_heads(text, target)
        stack = []
        j = 0
        while j < target
          case text[j]
          when '\\' then j += 1
          when '[' then j = class_end(text, j) - 1
          when '(' then stack << text[j, 4]
          when ')' then stack.pop
          end
          j += 1
        end
        stack
      end

      # +text+ with every lookbehind opener read as the matching lookahead (for validation).
      def as_lookaheads(text)
        out = +''
        j = 0
        while j < text.length
          if text[j] == '\\'
            out << text[j, 2]
            j += 2
          elsif text[j] == '['
            stop = class_end(text, j)
            out << text[j...stop]
            j = stop
          elsif text[j, 4] == '(?<=' || text[j, 4] == '(?<!'
            out << '(?' << text[j + 3]
            j += 4
          else
            out << text[j]
            j += 1
          end
        end
        out
      end

      # What in an emulated lookbehind body reads differently left to right than .NET's
      # right-to-left lookbehind: an atomic group, a back-reference (to a group outside it,
      # or captured in the other order), a named group (it would vanish from the variants'
      # numbering) or a conditional. @return [String, nil]
      def unsound_body(body)
        j = 0
        while j < body.length
          case body[j]
          when '\\'
            return 'a back-reference' if body[j + 1].to_s.match?(/[1-9k]/)

            j += 1
          when '[' then j = class_end(body, j) - 1
          when '('
            return 'an atomic group' if body[j, 3] == '(?>'
            return 'a named group' if body[j..].match?(NAMED_GROUP)
            return 'a conditional' if body[j, 3] == '(?('
          end
          j += 1
        end
        nil
      end

      # A back-reference to a capture a rewritten lookbehind lost reads "" (the
      # placeholder) where .NET reads the captured text. @return [String, nil] the reason
      def placeholder_reference(text, placeholders)
        return nil if placeholders.empty?

        numbers = []
        refs = []
        j = 0
        while j < text.length
          case text[j]
          when '\\'
            digits = text[(j + 1)..][/\A(?:\d+|k<\d+>|k'\d+')/]
            refs << digits.delete("k<>'").to_i if digits && digits != '0' && !digits.start_with?('0')
            j += 1
          when '[' then j = class_end(text, j) - 1
          when '('
            numbers << j if text[j + 1] != '?'
          end
          j += 1
        end
        lost = placeholders.map { |at| numbers.index(at).to_i + 1 }
        # .NET reads `\12` as group 12 when it exists, else as \1 then "2".
        refs.map! { |n| n <= numbers.length ? n : n.to_s[0].to_i }
        (refs & lost).empty? ? nil : 'a back-reference to a capture inside a rewritten lookbehind'
      end

      # Width of the element (atom or closed group, with its quantifier) at text[j].
      # @return [[Integer, Integer]] width (nil = variable), next index
      def element_width(text, j)
        case text[j]
        when '\\' then width, j = escape_width(text, j)
        when '[' then width, j = [1, class_end(text, j)]
        when '^', '$' then width, j = [0, j + 1]
        when '('
          close = group_close(text, j)
          return [nil, text.length] if close.nil?

          head = group_head(text, j)
          width = if head.nil? then nil
                  elsif LOOKAROUND_HEADS.include?(text[j, head]) || text[j, 3] == '(?#' then 0
                  else alternation_width(text, j + head, close)
                  end
          j = close + 1
        else width, j = [1, j + 1]
        end
        quantifier_width(text, j, width)
      end

      LOOKAROUND_HEADS = %w[(?= (?! (?<= (?<!].freeze

      # Length of the group opener at text[j] ('(', '(?:', '(?<name>', '(?i-s:', '(?=', ...);
      # nil for a construct whose width this does not model (conditionals).
      def group_head(text, j)
        rest = text[j..]
        head = rest[/\A\((?:\?(?:[:>=!]|<[=!]|<\w+>|'\w+'|[imx]*(?:-[imx]*)?:|#))?/]
        return nil if head.nil? || (head == '(' && rest[1] == '?')

        head.length
      end

      # Common width of the alternatives in text[from...to]; nil when they differ or vary.
      def alternation_width(text, from, to)
        widths = top_level_split(text[from...to]).map do |alt|
          width = 0
          j = 0
          while j < alt.length
            element, j = element_width(alt, j)
            break width = nil if element.nil?

            width += element
          end
          width
        end
        widths.uniq.length == 1 ? widths.first : nil
      end

      # A quantifier at text[j] applied to an element of +width+ (nil = variable).
      # @return [[Integer, Integer]] resulting width (nil = variable), next index
      def quantifier_width(text, j, width)
        if (brace = text[j..][NET_BRACE_QUANTIFIER])
          j += brace.length
          j += 1 if text[j] == '?'
          low, high = brace[1...-1].split(',', -1)
          fixed = high.nil? || high == low
          return [width && (width.zero? || fixed) ? width * low.to_i : nil, j]
        end
        return [width, j] unless '*+?'.include?(text[j].to_s) && !text[j].nil?

        j += 1
        j += 1 if text[j] == '?'
        [width&.zero? ? 0 : nil, j]
      end

      # Width of the escape at text[j] (translated text). @return [[Integer, Integer]]
      def escape_width(text, j)
        n = text[j + 1].to_s
        case n
        when 'b', 'B', 'A', 'z', 'Z', 'G' then [0, j + 2]
        when /[1-9]/, 'k' then [nil, j + 2] # back-reference
        when 'p', 'P' then [1, (text.index('}', j) || j) + 1]
        when 'x' then [1, j + 4]
        when 'u' then [1, j + 6]
        when 'c' then [1, j + 3]
        else [1, j + 2]
        end
      end

      # A pattern Onigmo cannot hold in one Regexp because of variable-length lookbehinds
      # (.NET-valid, e.g. GenieHunter hunt.cmd:309 `(?<!arisen \S+ )zombie(?!\s)` reached
      # through %critters). Each such lookbehind sits at a FIXED distance from the match start
      # ({NetRegex.fixed_offset}), so for a candidate start s its truth is one test: does its
      # body match text ending exactly at s + distance p? (`(?:X)\z` on the first p characters;
      # a body that looks past its end -- lookahead, `$`, `\b` ... -- is matched on the whole
      # line as `(?:X)(?<=\A.{p})`, like .NET's right-to-left lookbehind.) The pattern is compiled per
      # truth combination with each lookbehind replaced by "" (holds) or `(?!)` (fails),
      # captures and numbering untouched -- lazily, only the combinations a line needs, so
      # there is no cap on the number of lookbehinds. A relaxed variant (every lookbehind
      # assumed to hold, or to fail inside an odd number of negative lookarounds: a
      # superset either way) finds candidate starts left to right and the variant for that
      # start's truths decides, anchored with `\G` -- which is exactly .NET's leftmost-first
      # search, alternatives and backtracking included. Where holding can also make the
      # pattern match less ({NetRegex.non_monotone?}: atomic group, lookahead, conditional)
      # the relaxed variant is no superset and every start is tried instead. When a lookbehind has no fixed
      # distance (inside a quantified group, after a variable-width part of its own
      # alternative) or its body reads differently left to right ({NetRegex.unsound_body})
      # {#reason} names why and {NetRegex.compile} returns {Unsupported}.
      #
      # Shared between threads through {NetRegex::CACHE}: the lazily compiled regexes are
      # memoized under a lock. The cached instance has no match timeout; {#with_timeout} makes a
      # private copy whose every internal regex carries one and whose candidate walk has a
      # deadline (the display gags/substitutes, {StreamFilters}: Lich's parser thread must not
      # stall on a pattern Onigmo backtracks catastrophically).
      class Emulated
        Check = Struct.new(:negative, :offset, :body, :prefix, :regexes)

        attr_reader :source, :reason

        # @param text [String] the translated pattern, lookbehinds still in place
        # @param lookbehinds [Array<Lookbehind>]
        # @param options [Integer, nil] Regexp options
        # @return [Emulated]
        # @raise [RegexpError] when even the relaxed variant does not compile (the failure
        #   is something else: invalid)
        def self.build(text, lookbehinds, options)
          new(text, lookbehinds, options)
        end

        # @param timeout [Float, nil] seconds each match may take (see {#with_timeout})
        def initialize(text, lookbehinds, options, timeout: nil)
          @source = text
          @lookbehinds = lookbehinds
          @options = options
          @timeout = timeout
          @lock = Mutex.new
          @variants = {}
          @any = regexp(variant(lookbehinds.map { |lb| !NetRegex.negated?(text, lb.start) }))
          @exhaustive = lookbehinds.any? { |lb| NetRegex.non_monotone?(text, lb.start) }
          @reason = sound
        end

        # @return [Float, nil] the match timeout of this copy (nil: none, the shared cached one)
        attr_reader :timeout

        # A copy of this pattern whose {#match} raises Regexp::TimeoutError once it has run
        # +seconds+: each internal regex gets Regexp#timeout +seconds+ and the walk over candidate
        # starts stops at a deadline +seconds+ after the call. The deadline is only checked between
        # candidate starts, and one start runs the relaxed search, one test per lookbehind and the
        # variant match, each of which may take up to +seconds+ -- so one match costs at most about
        # (lookbehinds + 2) x +seconds+. The receiver (shared through
        # {NetRegex::CACHE}) is not changed.
        # @param seconds [Float]
        # @return [Emulated]
        def with_timeout(seconds)
          self.class.new(@source, @lookbehinds, @options, timeout: seconds)
        end

        # @param str [String]
        # @param pos [Integer] where the search starts (the text before it is still seen by
        #   the lookbehinds, as with .NET's Match(input, startat))
        # @return [MatchData, nil] the .NET match (groups numbered as in .NET)
        def match(str, pos = 0)
          return nil if @reason

          str = str.to_s
          deadline = @timeout && (Process.clock_gettime(Process::CLOCK_MONOTONIC) + @timeout)
          from = pos
          while from <= str.length
            raise Regexp::TimeoutError, 'regexp match timeout' if deadline && Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

            start = @exhaustive ? from : @any.match(str, from)&.begin(0)
            return nil if start.nil?

            truths = @checks.map { |check| holds?(check, str, start) }
            hit = variant_regex(truths).match(str, start)
            return hit if hit

            from = start + 1
          end
          nil
        end

        # @param str [String]
        # @return [Boolean]
        def match?(str)
          !match(str).nil?
        end

        private

        def variant(truths)
          out = @source.dup
          @lookbehinds.zip(truths).reverse_each do |lb, truth|
            out[lb.start, lb.span] = truth ? '(?:)' : '(?!)'
          end
          out
        end

        def variant_regex(truths)
          @lock.synchronize { @variants[truths] ||= regexp("\\G(?:#{variant(truths)})") }
        end

        # Regexp.new with this copy's options and timeout.
        def regexp(source)
          @timeout ? Regexp.new(source, @options, timeout: @timeout) : Regexp.new(source, @options)
        end

        # @return [String, nil] why a lookbehind cannot be emulated, nil when all can (then
        #   @checks holds one {Check} per lookbehind)
        def sound
          @checks = @lookbehinds.map do |lb|
            construct = NetRegex.unsound_body(lb.body)
            return "a variable-length lookbehind containing #{construct}" if construct

            offset = NetRegex.fixed_offset(@source, lb.start)
            return "a variable-length lookbehind #{offset}" if offset.is_a?(String)

            body = check_body(lb)
            begin
              prefix_form = regexp("#{body}\\z") unless NetRegex.looks_right?(lb.body)
              Regexp.new("#{body}(?<=\\A(?m:.){0})", @options)
            rescue RegexpError
              return 'a variable-length lookbehind whose body Onigmo cannot compile on its own'
            end
            Check.new(lb.negative, offset, body, prefix_form, {})
          end
          nil
        end

        def check_body(lb)
          case lb.icase
          when true then "(?i:#{lb.body})"
          when false then "(?-i:#{lb.body})"
          else "(?:#{lb.body})"
          end
        end

        # Does the lookbehind hold at +start+? Its body must match text ending exactly at
        # +at+. A body that only looks left is matched, `\z`-anchored, against the text before
        # +at+: one Regexp, linear-ish per line. One that looks past
        # its end ({NetRegex.looks_right?}) needs the whole line: matched there with the end
        # pinned by a fixed-width lookbehind, one Regexp per distance.
        def holds?(check, str, start)
          at = start + check.offset
          found = at <= str.length &&
                  (check.prefix ? check.prefix.match?(str[0, at]) : check_regex(check, at).match?(str))
          check.negative ? !found : found
        end

        def check_regex(check, at)
          @lock.synchronize { check.regexes[at] ||= regexp("#{check.body}(?<=\\A#{exactly(at)})") }
        end

        # `(?m:.)` +n+ times, in chunks within Onigmo's repeat limit (100000).
        def exactly(n)
          ("(?m:.){#{REPEAT_MAX}}" * (n / REPEAT_MAX)) + "(?m:.){#{n % REPEAT_MAX}}"
        end

        REPEAT_MAX = 100_000
      end

      # A .NET-valid pattern the translation cannot reproduce ({Emulated#reason}, the n option):
      # it never matches. The caller registers it anyway (Remix would) and prints {#warning}
      # once instead of aborting the script.
      class Unsupported
        attr_reader :pattern, :reason

        def initialize(pattern, reason)
          @pattern = pattern
          @reason = reason
        end

        def match(_str, _pos = 0) = nil
        def match?(_str) = false

        # @param where [String] what registered it ("action", "matchre", ...)
        # @return [String]
        def warning(where)
          "[Genie: #{where} pattern uses #{reason}, which the in-Lich engine cannot match; it will never fire: #{pattern}]"
        end
      end
    end
  end
end
