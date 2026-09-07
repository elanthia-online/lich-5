# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/defs/pattern_gate'
require 'gemstone/combat/defs/attacks'
require 'gemstone/combat/defs/statuses'

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
  end

  describe '.build / .rejects?' do
    it 'sends patterns without a usable literal to always_scan' do
      gate, always = described_class.build([/ab|cd/, /a long literal here/])
      expect(always).to eq([/ab|cd/])
      expect(gate).to match('xx a long literal here xx')
    end

    it 'never rejects when always_scan is non-empty' do
      gate, always = described_class.build([/ab|cd/])
      expect(described_class.rejects?(gate, always, 'anything')).to be false
    end

    it 'rejects lines containing no gate literal' do
      gate, always = described_class.build([/You swing .+? at (?<t>[^!]+)!/])
      expect(described_class.rejects?(gate, always, 'the quick brown fox')).to be true
      expect(described_class.rejects?(gate, always, 'You swing a stick at it!')).to be false
    end
  end

  describe 'safety property over the real def files' do
    {
      'attacks'  => -> {
        a = Lich::Gemstone::Combat::Definitions::Attacks
        [a::ATTACK_LOOKUP.map(&:first), a::ATTACK_GATE, a::ATTACK_ALWAYS_SCAN]
      },
      'statuses' => -> {
        s = Lich::Gemstone::Combat::Definitions::Statuses
        [s::ALL_LOOKUP.map(&:first), s::STATUS_GATE, s::STATUS_ALWAYS_SCAN]
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
          else
            expect(always).to include(pattern)
          end
        end
      end
    end
  end
end
