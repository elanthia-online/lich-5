# frozen_string_literal: true

#
# PatternGate - builds cheap literal-substring pre-filters for pattern sets
#
# Union detectors built from the raw patterns (Regexp.union of alternatives
# with leading `(?<target>.+?)`) cost ~0.5-1ms per non-matching line: the
# engine retries the whole alternation from every character position. A union
# of the *literal fragments* extracted from each pattern costs ~7us per line
# on real game text (measured against session logs) and returns the same
# hit set, because a line can only match a pattern if it contains that
# pattern's longest literal run.
#
# Gates are derived automatically at load time, so new def patterns get
# gating for free and per-line cost stays flat as the def files grow.
#

module Lich
  module Gemstone
    module Combat
      module Definitions
        # Markup tolerance tokens for the live XML feed (round-6 sweep,
        # 46 def kinds proven markup-unsafe against 11.5GB of real logs).
        # Entity pronouns arrive wrapped in links - creature and player
        # alike - as <pushBold/><a exist=...>her</a><popBold/>, and a
        # possessive keeps its 's INSIDE the link, closing before the
        # next word (<a ...>Nisugi's</a> blow). Interpolate MK_PRE before
        # a bare pronoun and MK_POST after a pronoun or possessive 's.
        # Both are fully optional, so stripped-text matching is unchanged.
        # When the exist id matters, put MK_PRE inside the capture.
        MK_PRE  = '(?:<pushBold/>)?(?:<a [^>]*>)?'
        MK_POST = '(?:</a>)?(?:<popBold/>)?'

        # One assembled pattern table: the flattened lookup rows (pattern
        # first, then whatever the def kind carries) together with the
        # PatternGate derived from them. Each def module binds one of these
        # to a constant in a SINGLE assignment and its consumers read that
        # constant once per call, so a hot reload (`;hmr combat/defs/`,
        # Tracker.reload_defs!) never pairs a lookup from one build with a
        # gate from another, and a load that fails part-way leaves the
        # previous complete table live.
        Table = Struct.new(:lookup, :gate, :always_scan) do
          # True when the line cannot match any pattern in this table.
          def rejects?(line) = PatternGate.rejects?(gate, always_scan, line)
        end

        module PatternGate
          module_function

          # Longest guaranteed-literal run in a regex source, or nil when no
          # safe literal exists. Character classes, escapes and then entire
          # parenthesized groups (innermost-out, so nesting works) are removed
          # wholesale - text inside a group may be optional or one alternation
          # branch, so it is never guaranteed. What survives is top-level text
          # that every match must contain; the longest metachar-free fragment
          # of it is the gate literal. A source with a top-level `|` is a pure
          # alternation with no guaranteed text - returns nil (always scan).
          def longest_literal(regex)
            source = regex.source.dup
            source.gsub!(/\\[A-Za-z]/, "\x00")        # escape sequences (\d, \w, \b...)
            source.gsub!(/\[[^\]]*\]/, "\x00")        # character classes
            # Remove groups innermost-first so nested groups collapse cleanly
            nil while source.gsub!(/\((?:\?(?:<[a-zA-Z_]+>|:|=|!))?[^()]*\)/, "\x00")
            return nil if source.include?('|') # top-level alternation
            fragments = source.split(/[\\(){}?*+.^$\x00]/)
            # A fragment followed by ? or * in the original is optional; the
            # split above already breaks on those metachars, but the char
            # BEFORE ? belongs to the fragment - trim it to stay conservative.
            longest = fragments.max_by(&:length).to_s
            longest = longest[0..-2] if source =~ /#{Regexp.escape(longest)}[?*]/
            longest.empty? ? nil : longest
          end

          # Build a gate for a list of patterns. Returns [union_regex, always_scan]
          # where union_regex matches iff some pattern's literal is present, and
          # always_scan lists patterns whose literal was too short to be a
          # useful gate (they must be tried on every line).
          MIN_LITERAL = 4

          # True when +regex+ matches without regard to case, whether that
          # was set as an option (//i, Regexp::IGNORECASE) or written inline
          # as a global (?i) -- the inline form rides in the source and
          # leaves options untouched. A scoped (?i:...) is not global, and
          # its group is stripped out of the literal anyway.
          def case_folded?(regex)
            return true if (regex.options & Regexp::IGNORECASE) != 0

            # Flags may be followed by a `-` group turning others off, as in
            # (?i-m); `i` before the dash still folds the whole pattern.
            regex.source.match?(/\(\?[a-z]*i[a-z]*(?:-[a-z]*)?\)/)
          end

          def build(patterns)
            literals = []
            folded = []
            always_scan = []
            patterns.each do |pattern|
              literal = longest_literal(pattern)
              if literal && literal.length >= MIN_LITERAL
                # A case-folded pattern's literal has to be matched the same
                # way, or the gate rejects lines the pattern itself matches
                # (/ZEPHYR chills/i against "zephyr chills ..."). Folded
                # literals go into their own case-insensitive union rather
                # than sending the whole pattern to always_scan, which would
                # put every def of a case-folded family back on full scan.
                (case_folded?(pattern) ? folded : literals) << literal
              else
                always_scan << pattern
              end
            end
            [union_of(literals, folded), always_scan.freeze]
          end

          # One gate regex covering both unions, or nil when there are no
          # literals at all.
          def union_of(literals, folded)
            exact = literals.empty? ? nil : Regexp.union(literals.uniq)
            loose = folded.empty? ? nil : Regexp.new(Regexp.union(folded.uniq).source, Regexp::IGNORECASE)
            return nil unless exact || loose
            return exact.freeze unless loose
            return loose.freeze unless exact

            Regexp.union(exact, loose).freeze
          end

          # Convenience: true when the line can't possibly match any pattern in
          # this table, so the caller may skip the full scan. A line is only
          # rejectable when BOTH the literal gate misses AND no ungated
          # (always_scan) pattern matches. Any always_scan pattern that matches
          # keeps the line in play; a non-empty always_scan does NOT blanket-
          # disable rejection (that was the old bug - it reverted the whole
          # table to full-scan the moment one short-literal pattern existed).
          # A pattern that exceeds its evaluation budget must cost that one
          # pattern and nothing else: not the facts a line already yielded,
          # not the defs after it, and not the worker's remaining work. Both
          # helpers skip the offending pattern for this line and report it
          # once per source, through Supplements so the dedup set and its
          # reset-on-reload are shared with the compile-time reports.
          #
          # @return [MatchData, nil]
          def safe_match(pattern, line)
            pattern.match(line)
          rescue Regexp::TimeoutError
            report_timeout(pattern)
            nil
          end

          # @return [Boolean] false when the pattern timed out
          def safe_match?(pattern, line)
            pattern.match?(line)
          rescue Regexp::TimeoutError
            report_timeout(pattern)
            false
          end

          def report_timeout(pattern)
            Supplements.report_match_timeout(pattern) if defined?(Supplements)
          end

          def rejects?(gate, always_scan, line)
            # A timeout anywhere in the gate leaves the answer UNDECIDED, so
            # the line goes to the full scan rather than being rejected:
            # deciding not to scan would hide every def behind this gate.
            # That scan re-evaluates the same pattern under safe_match,
            # which is where it gets reported. Distinguishing a timeout from
            # an honest non-match is the whole point -- safe_match?'s false
            # cannot tell them apart, so the raise is caught here.
            return false if gate && timeout_tolerant_match?(gate, line) != false

            always_scan.all? { |rx| timeout_tolerant_match?(rx, line) == false }
          end

          # @return [Boolean, nil] true/false as matched, nil on a timeout
          def timeout_tolerant_match?(pattern, line)
            pattern.match?(line)
          rescue Regexp::TimeoutError
            report_timeout(pattern)
            nil
          end

          # Regexp.union of +patterns+, or nil when they cannot be combined.
          #
          # A pattern that is perfectly valid on its own can still be
          # illegal inside a union: a numbered backreference beside a
          # named capture raises RegexpError ("numbered backref/call is not
          # allowed"). Since a supplement may contribute either, a union of
          # user and shipped patterns is not guaranteed to compile, and the
          # caller gets nil rather than an exception.
          #
          # @param patterns [Array<Regexp>]
          # @param label [String] named in the report when the union fails
          # @return [Regexp, nil] frozen
          def union_or_nil(patterns, label)
            Regexp.union(patterns).freeze
          rescue RegexpError => e
            Supplements.report_union_failure(label, e) if defined?(Supplements)
            nil
          end
        end
      end
    end
  end
end
