# frozen_string_literal: true

require_relative '../../../spec_helper'
require 'gemstone/combat/parser'

# parse_spell_loss consults Tracker.settings at call time; supply them
# headless the way processor_inbound_spec does
module Lich
  module Gemstone
    module Combat
      unless defined?(Tracker)
        module Tracker
          def self.settings = { track_statuses: true }
          def self.debug?(*) = false
        end
      end
    end
  end
end

# Spell-loss defs pinned against real game messaging (2026-09-04 multi-
# chunk sweep + cross-log timestamp pairing). Each line converts only
# once identified as a specific spell's third-person wear-off.
RSpec.describe Lich::Gemstone::Combat::Parser do
  def bolded(id, noun, name)
    %(<pushBold/><a exist="#{id}" noun="#{noun}">#{name}</a><popBold/>)
  end

  describe '.parse_spell_loss' do
    it 'identifies Empathic Focus (1109) off a creature, pronoun link intact' do
      line = "#{bolded(452443346, 'psionicist', 'An ethereal triton psionicist')} loses <a exist=\"452443346\" noun=\"psionicist\">its</a> focused look."
      result = described_class.parse_spell_loss(line)
      expect(result).not_to be_nil
      expect(result[:spell]).to eq(1109)
      expect(result[:id]).to eq(452443346)
    end

    it 'identifies Empathic Focus (1109) off a player in plain text' do
      result = described_class.parse_spell_loss('Nisugi loses his focused look.')
      expect(result).not_to be_nil
      expect(result[:spell]).to eq(1109)
      expect(result[:id]).to be_nil
      expect(result[:name]).to eq('Nisugi')
    end

    it 'identifies Strength of Will (1119)' do
      line = "#{bolded(98732276, 'shield-maiden', 'A brawny gigas shield-maiden')} loses an aura of resolve."
      result = described_class.parse_spell_loss(line)
      expect(result).not_to be_nil
      expect(result[:spell]).to eq(1119)
      expect(result[:spell_name]).to eq('Strength of Will')
      expect(result[:id]).to eq(98732276)
    end

    it 'identifies Intensity (1130)' do
      line = "#{bolded(452450877, 'wendigo', 'A savage fork-tongued wendigo')} loses an intense expression."
      result = described_class.parse_spell_loss(line)
      expect(result).not_to be_nil
      expect(result[:spell]).to eq(1130)
      expect(result[:id]).to eq(452450877)
    end

    it 'identifies Foresight (1204) - wording from the 2020-12-26 ball log' do
      result = described_class.parse_spell_loss(
        'Laehna takes a deep breath, blinking a couple of times before resuming a calm expression.'
      )
      expect(result).not_to be_nil
      expect(result[:spell]).to eq(1204)
      expect(result[:name]).to eq('Laehna')
    end

    it 'identifies Spirit Warding II (107) in both observed forms' do
      %w[
        Deep\ blue\ motes\ swirl\ away\ from\ Laehna\ and\ fade.
        The\ deep\ blue\ glow\ leaves\ Tylanthriel.
      ].each do |line|
        result = described_class.parse_spell_loss(line)
        expect(result).not_to be_nil, "expected match for: #{line}"
        expect(result[:spell]).to eq(107)
      end
    end

    it 'identifies Lesser Shroud (120) in both forms per the Dispel flare page' do
      ['The very powerful look leaves Roelon.', 'The white light leaves Roelon.'].each do |line|
        result = described_class.parse_spell_loss(line)
        expect(result).not_to be_nil, "expected match for: #{line}"
        expect(result[:spell]).to eq(120)
        expect(result[:name]).to eq('Roelon')
      end
    end

    it 'identifies Dragonclaw (1209) and Brace (1214) wiki wear-offs' do
      r1 = described_class.parse_spell_loss("The scales covering Abrogate's hands turn brittle and flake away.")
      expect(r1).not_to be_nil
      expect(r1[:spell]).to eq(1209)
      r2 = described_class.parse_spell_loss("The thick plates of bone around Abrogate's forearms begin to crack, then shatter into a fine white dust.")
      expect(r2).not_to be_nil
      expect(r2[:spell]).to eq(1214)
    end

    it 'identifies Soul Ward (319) collapse on a creature' do
      line = "The air about #{bolded(452450877, 'grotesque', 'a horned basalt grotesque')} shimmers momentarily before the evanescent shield surrounding it collapses."
      result = described_class.parse_spell_loss(line)
      expect(result).not_to be_nil
      expect(result[:spell]).to eq(319)
      expect(result[:id]).to eq(452450877)
    end

    it 'identifies Mindward (1208) across observed line colors' do
      ['blue', 'purple', 'jade green', 'snow white'].each do |color|
        line = "A series of #{color} lines suddenly appears on Abrogate's face, quickly racing towards the center of his forehead before detaching and dissipating in the air."
        result = described_class.parse_spell_loss(line)
        expect(result).not_to be_nil, "expected match for color: #{color}"
        expect(result[:spell]).to eq(1208)
      end
    end

    it 'identifies the round-2 effect-list pins (513, 911, 1605)' do
      cases = {
        'A grim gigas skald no longer bristles with energy.'                                                                          => 513,
        'Laehna becomes solid again.'                                                                                                 => 911,
        "Talliver's movements no longer appear to be influenced by a divine power as the spiritual force fades from around his arms." => 1605
      }
      cases.each do |line, spell|
        result = described_class.parse_spell_loss(line)
        expect(result).not_to be_nil, "expected match for: #{line}"
        expect(result[:spell]).to eq(spell)
      end
    end

    it 'identifies the generic unspecified-spell wear-off with spell: nil' do
      ['Perigourd appears somehow different.',
       'A shan shaman seems slightly different.'].each do |line|
        result = described_class.parse_spell_loss(line)
        expect(result).not_to be_nil, "expected match for: #{line}"
        expect(result[:spell]).to be_nil
        expect(result[:spell_name]).to eq('unknown')
      end
    end

    it 'does not claim unpinned wear-off residue' do
      expect(described_class.parse_spell_loss('The elemental aura around a triton dissembler wavers.')).to be_nil
      expect(described_class.parse_spell_loss('A hazy film coats a triton dissembler.')).to be_nil
    end

    it 'returns nil when status tracking is disabled' do
      allow(Lich::Gemstone::Combat::Tracker).to receive(:settings)
        .and_return({ track_statuses: false })
      expect(described_class.parse_spell_loss('Nisugi loses his focused look.')).to be_nil
    end
  end
end
