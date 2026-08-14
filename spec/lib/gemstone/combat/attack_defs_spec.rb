# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/defs/attacks'
require 'gemstone/combat/parser'

# Attack def coverage pinned against real game messaging (lines lifted from
# GSIV session logs, XML links intact where the game sends them). When log
# replay surfaces an unmatched variant of one of our own attacks, the fix is
# a def change - these examples keep known variants from regressing.
RSpec.describe Lich::Gemstone::Combat::Parser do
  def bolded(id, noun, name)
    %(<pushBold/><a exist="#{id}" noun="#{noun}">#{name}</a><popBold/>)
  end

  describe '.parse_attack' do
    it 'matches the summoned briar dragging its victim to the ground' do
      line = "The lashing emerald briar lashes out violently at #{bolded(452443346, 'warg', 'a niveous giant warg')}, dragging it to the ground!"
      result = described_class.parse_attack(line)
      expect(result).not_to be_nil
      expect(result[:name]).to eq(:tangleweed)
      expect(result[:target][:id]).to eq(452443346)
    end

    it 'matches the summoned briar dragging its victim to the floor (variant found in 2026-01 logs)' do
      line = "The lashing emerald briar lashes out violently at #{bolded(452443346, 'warg', 'a niveous giant warg')}, dragging it to the floor!"
      result = described_class.parse_attack(line)
      expect(result).not_to be_nil
      expect(result[:name]).to eq(:tangleweed)
      expect(result[:target][:id]).to eq(452443346)
    end

    it 'matches the briar entangle variant' do
      line = "The lashing emerald briar lashes out at #{bolded(452440152, 'mastodon', 'a heavily armored battle mastodon')}, wraps itself around its body and entangles it on the ground."
      result = described_class.parse_attack(line)
      expect(result).not_to be_nil
      expect(result[:name]).to eq(:tangleweed)
      expect(result[:target][:id]).to eq(452440152)
    end

    it 'matches the classic ewave messaging' do
      line = "#{bolded(98732276, 'shield-maiden', 'A brawny gigas shield-maiden')} is buffeted by the churning ethereal waves and is knocked to the ground."
      result = described_class.parse_attack(line)
      expect(result).not_to be_nil
      expect(result[:name]).to eq(:ewave)
    end

    it 'matches the dark ewave variants found in 2026 logs (waves and sphere)' do
      ['formless black waves', 'formless black sphere'].each do |phrase|
        line = "#{bolded(98732276, 'shield-maiden', 'A brawny gigas shield-maiden')} is buffeted by the #{phrase} and is knocked to the ground."
        result = described_class.parse_attack(line)
        expect(result).not_to be_nil, "expected match for #{phrase}"
        expect(result[:name]).to eq(:ewave)
      end
    end

    it 'does not claim ambient spell messaging with no caster attribution' do
      # "Bloodstained light" fires identically for ANY caster's spell (seen
      # after both "Dicate gestures at..." and "You gesture at..." in logs),
      # so it must not be parsed as one of our attacks.
      line = "Bloodstained light spills down from the heavens in an undulating deluge, bathing #{bolded(416226445, 'skald', 'a grim gigas skald')}'s form in a cascade of transcendent power!"
      expect(described_class.parse_attack(line)).to be_nil
    end
  end
end
