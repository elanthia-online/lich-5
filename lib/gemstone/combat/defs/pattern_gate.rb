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

          def build(patterns)
            literals = []
            always_scan = []
            patterns.each do |pattern|
              literal = longest_literal(pattern)
              if literal && literal.length >= MIN_LITERAL
                literals << literal
              else
                always_scan << pattern
              end
            end
            [literals.empty? ? nil : Regexp.union(literals.uniq).freeze, always_scan.freeze]
          end

          # Convenience: true when the line can't possibly match any gated
          # pattern (no literal present and no ungated patterns exist).
          def rejects?(gate, always_scan, line)
            always_scan.empty? && (gate.nil? || !gate.match?(line))
          end
        end
      end
    end
  end
end
