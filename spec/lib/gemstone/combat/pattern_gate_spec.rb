# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/defs/pattern_gate'
require 'gemstone/combat/defs/attacks'
require 'gemstone/combat/defs/statuses'
require 'gemstone/combat/defs/messages'

# PatternGate derives literal-substring pre-filters from def patterns. The
# safety property is: the gate must NEVER reject a line that some pattern
# would match (false accepts are fine - they just fall through to the full
# scan). These specs pin the extraction rules that guarantee it.
RSpec.describe Lich::Gemstone::Combat::Definitions::PatternGate do
  describe '.longest_literal' do
    it 'extracts the longest top-level literal run' do
      expect(described_class.longest_literal(/You swing .+? at (?<target>[^!]+)!/))
        .to eq('You swing ')
    end

    it 'ignores text inside optional groups (not guaranteed present)' do
      expect(described_class.longest_literal(/You(?: make a precise attempt)? jab (?<t>[^!]+)!/))
        .to eq(' jab ')
    end

    it 'ignores text inside alternation groups (only one branch matches)' do
      expect(described_class.longest_literal(/x(?:a much longer branch|b) hits!/))
        .to eq(' hits!')
    end

    it 'returns nil for a pure top-level alternation (no guaranteed text)' do
      expect(described_class.longest_literal(/first branch|second branch/)).to be_nil
    end

    it 'does not treat character-class content as literal text' do
      expect(described_class.longest_literal(/[abcdefgh]+ falls down\./)).to eq(' falls down')
    end

    it 'trims a trailing character that is optional in the source' do
      expect(described_class.longest_literal(/points? of damage/)).to eq(' of damage')
    end

    it 'extracts the literal from a case-folded pattern too (build matches it case-insensitively)' do
      expect(described_class.longest_literal(/ZEPHYR chills (?<target>.+)/i)).to eq('ZEPHYR chills ')
      expect(described_class.longest_literal(/(?i)ZEPHYR chills (?<target>.+)/)).to eq('ZEPHYR chills ')
    end
  end

  # A literal lifted out of a case-folded pattern has to be matched the same
  # way. Gating /ZEPHYR chills/i on a case-sensitive "ZEPHYR chills" rejects
  # "zephyr chills a kobold" -- a line the pattern itself matches -- and
  # sending the whole pattern to always_scan instead would put every def of
  # a case-folded family back on a full scan of every line.
  describe '.case_folded?' do
    it 'recognises the option-setting and inline-global spellings' do
      expect(described_class.case_folded?(/x/i)).to be(true)
      expect(described_class.case_folded?(Regexp.new('x', Regexp::IGNORECASE))).to be(true)
      expect(described_class.case_folded?(/(?i)x/)).to be(true)
      expect(described_class.case_folded?(/(?mi)x/)).to be(true)
    end

    it 'does not treat a plain pattern or a scoped group as globally folded' do
      expect(described_class.case_folded?(/x/)).to be(false)
      expect(described_class.case_folded?(/(?i:x)y/)).to be(false)
      expect(described_class.case_folded?(/(?<name>x)y/)).to be(false)
    end

    it 'sees the fold when other flags are switched off in the same group' do
      # (?i-m) folds case and unsets multiline; the dash must not hide the i.
      expect(described_class.case_folded?(/(?i-m)ZEPHYR chills/)).to be(true)
      expect(described_class.case_folded?(/(?x-i)ZEPHYR chills/)).to be(false)
      gate, always = described_class.build([/(?i-m)ZEPHYR chills (?<t>.+)/])
      expect(always).to be_empty
      expect(described_class.rejects?(gate, always, 'zephyr chills a kobold')).to be(false)
    end
  end

  describe '.build / .rejects?' do
    it 'gates a case-folded pattern without rejecting the lines it matches' do
      pattern = /(?i)ZEPHYR chills (?<target>.+)/
      gate, always = described_class.build([pattern])

      expect(pattern.match('zephyr chills a kobold')).not_to be_nil
      expect(described_class.rejects?(gate, always, 'zephyr chills a kobold')).to be(false)
      # Still gated, not dumped onto every line as a full scan.
      expect(always).to be_empty
      expect(described_class.rejects?(gate, always, 'nothing relevant here')).to be(true)
    end

    it 'keeps folded and exact literals in one gate without loosening the exact ones' do
      gate, always = described_class.build([/ZEPHYR chills/i, /PLAIN literal here/])
      expect(always).to be_empty
      expect(described_class.rejects?(gate, always, 'zephyr chills')).to be(false)
      expect(described_class.rejects?(gate, always, 'PLAIN literal here')).to be(false)
      # The case-sensitive pattern keeps its case sensitivity.
      expect(described_class.rejects?(gate, always, 'plain literal here')).to be(true)
    end

    it 'sends patterns without a usable literal to always_scan' do
      gate, always = described_class.build([/ab|cd/, /a long literal here/])
      expect(always).to eq([/ab|cd/])
      expect(gate).to match('xx a long literal here xx')
    end

    it 'keeps a line an always_scan pattern matches, even with no gate literal' do
      # /ab|cd/ has no usable literal -> it lands in always_scan. A line the
      # pattern matches must NOT be rejected (that would drop a real match).
      gate, always = described_class.build([/ab|cd/])
      expect(always).to eq([/ab|cd/])
      expect(described_class.rejects?(gate, always, 'has cd inside')).to be false
    end

    it 'still rejects a line no always_scan pattern matches (the fast path)' do
      # This is the case the old contract got wrong: a non-empty always_scan
      # must not blanket-disable rejection. A line matching neither the gate
      # nor any always_scan pattern is still safely skippable.
      gate, always = described_class.build([/ab|cd/])
      expect(described_class.rejects?(gate, always, 'nothing relevant here')).to be true
    end

    it 'a non-empty always_scan does not disable the gate fast path for other patterns' do
      # gated literal pattern + an ungated alternation together: a line with
      # neither the literal nor an always_scan match is rejected.
      gate, always = described_class.build([/You swing .+? at (?<t>[^!]+)!/, /ab|cd/])
      expect(always).to eq([/ab|cd/])
      expect(described_class.rejects?(gate, always, 'the quick brown fox')).to be true
      expect(described_class.rejects?(gate, always, 'You swing a stick at it!')).to be false
      expect(described_class.rejects?(gate, always, 'has cd inside')).to be false
    end

    it 'rejects lines containing no gate literal' do
      gate, always = described_class.build([/You swing .+? at (?<t>[^!]+)!/])
      expect(described_class.rejects?(gate, always, 'the quick brown fox')).to be true
      expect(described_class.rejects?(gate, always, 'You swing a stick at it!')).to be false
    end
  end

  # A pattern that exceeds its evaluation budget must cost that one pattern
  # and nothing else: not the facts a line already yielded, not the defs
  # after it, and not the worker's remaining work.
  describe 'timeout isolation' do
    def timing_out(source = 'slow')
      Regexp.new(source).tap do |rx|
        allow(rx).to receive(:match).and_raise(Regexp::TimeoutError)
        allow(rx).to receive(:match?).and_raise(Regexp::TimeoutError)
      end
    end

    it 'safe_match skips the offending pattern instead of raising' do
      expect(described_class.safe_match(timing_out, 'anything')).to be_nil
    end

    it 'safe_match? answers false rather than raising' do
      expect(described_class.safe_match?(timing_out, 'anything')).to be(false)
    end

    it 'a timed-out gate is undecided, so the family is still scanned' do
      # Rejecting here would hide every def behind this gate; the full scan
      # re-evaluates the same pattern under safe_match, which reports it.
      expect(described_class.rejects?(timing_out, [].freeze, 'a line')).to be(false)
    end

    it 'a timed-out always_scan pattern does not reject the line' do
      expect(described_class.rejects?(nil, [timing_out].freeze, 'a line')).to be(false)
    end

    it 'a later definition still matches after an earlier one times out' do
      bad = timing_out
      good = /(?<target>.+?) shivers uncontrollably\./
      line = 'a kobold shivers uncontrollably.'

      resolved = [[bad, :bad], [good, :good]].find { |rx, _n| described_class.safe_match(rx, line) }
      expect(resolved&.last).to eq(:good)
    end
  end

  # A pattern that is valid on its own can still be illegal inside a union:
  # a numbered backreference beside a named capture raises RegexpError. The
  # detectors are the only place a union of user and shipped patterns is
  # built, so they must not take the def file down with them.
  describe '.union_or_nil' do
    it 'returns the union when the patterns combine' do
      expect(described_class.union_or_nil([/abc/, /def/], 'test')).to be_a(Regexp)
    end

    it 'returns nil instead of raising when they cannot' do
      patterns = [/(?<target>.+?) shivers\./, /^(\w+) echoes \1$/]
      expect { Regexp.union(patterns) }.to raise_error(RegexpError)
      expect(described_class.union_or_nil(patterns, 'test')).to be_nil
    end
  end

  describe 'safety property over the real def files' do
    {
      'attacks'        => -> {
        a = Lich::Gemstone::Combat::Definitions::Attacks
        [a::ATTACK_LOOKUP.map(&:first), a::ATTACK_GATE, a::ATTACK_ALWAYS_SCAN]
      },
      'statuses'       => -> {
        s = Lich::Gemstone::Combat::Definitions::Statuses
        [s::ALL_LOOKUP.map(&:first), s::STATUS_GATE, s::STATUS_ALWAYS_SCAN]
      },
      # The message families carry the shipped case-folded patterns, so they
      # are where a gate that ignores casing shows up first.
      'message family' => -> {
        m = Lich::Gemstone::Combat::Definitions::Messages
        fam = m::FAMILIES.find { |f| f.defs.any? { |d| described_class.case_folded?(d.pattern) } } || m::FAMILIES.first
        [fam.defs.map(&:pattern), fam.gate, fam.always_scan]
      }
    }.each do |name, fetch|
      it "every #{name} pattern is either gated by a guaranteed literal or in always_scan" do
        patterns, gate, always = fetch.call
        patterns.each do |pattern|
          literal = described_class.longest_literal(pattern)
          if literal && literal.length >= described_class::MIN_LITERAL
            # the literal must be guaranteed: any line containing it passes
            # the gate, so lines matching the pattern are never rejected
            expect(gate).to match(literal)
            # and in whatever casing the pattern itself accepts, or the gate
            # would reject a line the pattern matches
            expect(gate).to match(literal.swapcase) if described_class.case_folded?(pattern)
          else
            expect(always).to include(pattern)
          end
        end
      end
    end
  end
end
