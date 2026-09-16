# frozen_string_literal: true

require_relative '../../spec_helper'
require 'gemstone/mana'

module Kernel
  def dothistimeout(_action, _timeout, _success_line); end unless method_defined?(:dothistimeout)
end

# Spell stand-in: Mana only asks known? and affordable?.
class FakeSpell
  attr_accessor :known, :affordable

  def initialize(known: true, affordable: true)
    @known = known
    @affordable = affordable
  end

  def known? = known
  def affordable? = affordable

  class << self
    attr_accessor :table

    def [](num) = (table || {})[num]
  end
end

RSpec.describe Lich::Gemstone::Mana do
  before do
    stub_const('Spell', FakeSpell)
    allow(described_class).to receive(:waitrt?)
    allow(described_class).to receive(:sleep)
    allow(described_class).to receive(:dothistimeout).and_return('An invigorating rush of mana pulses through you.')
    Spell.table = { 130 => Spell.new(known: true, affordable: false), 9825 => Spell.new(known: false) }
  end

  it 'pulses and reports mana gained' do
    expect(described_class).to receive(:dothistimeout).with('mana pulse', 2, described_class::PULSE_RESULT)
                                                      .and_return('An invigorating rush of mana pulses through you.')
    expect(described_class.pulse).to be true
  end

  it 'reports false when the game refuses' do
    allow(described_class).to receive(:dothistimeout).and_return("You're already at full mana.")
    expect(described_class.pulse).to be false
  end

  it 'reports false when nothing confirms' do
    allow(described_class).to receive(:dothistimeout).and_return(nil)
    expect(described_class.pulse).to be false
  end

  it 'waits out roundtime before sending' do
    expect(described_class).to receive(:waitrt?).ordered
    expect(described_class).to receive(:dothistimeout).ordered.and_return('An invigorating rush of mana pulses through you.')
    described_class.pulse
  end

  context 'given a spell' do
    it 'pulses when the spell is known and not affordable' do
      expect(described_class).to receive(:dothistimeout)
      expect(described_class.pulse(130)).to be true
    end

    it 'accepts a Spell object' do
      expect(described_class).to receive(:dothistimeout)
      described_class.pulse(Spell[130])
    end

    it 'does nothing when the spell is affordable' do
      Spell.table[130].affordable = true
      expect(described_class).not_to receive(:dothistimeout)
      expect(described_class.pulse(130)).to be false
    end

    it 'does nothing when the spell is unknown' do
      expect(described_class).not_to receive(:dothistimeout)
      expect(described_class.pulse(9825)).to be false
    end

    it 'does nothing for a spell number that does not exist' do
      expect(described_class).not_to receive(:dothistimeout)
      expect(described_class.pulse(1)).to be false
    end
  end

  it 'PULSE_RESULT matches every reply the game uses' do
    [
      'An invigorating rush of mana pulses through you.',
      'You are too mentally fatigued to attempt this ability.',
      "You're already at full mana.",
      'Your mana control skills are not yet advanced enough.',
    ].each { |line| expect(line).to match(described_class::PULSE_RESULT) }
  end
end
