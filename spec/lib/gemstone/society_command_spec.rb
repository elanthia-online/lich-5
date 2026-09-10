# frozen_string_literal: true

require_relative '../../spec_helper'

require 'util/util'
require 'gemstone/society'

# The command each society reader's +use+ sends, exposed so a caller can
# send and confirm on its own terms.
RSpec.describe Lich::Gemstone::Society do
  SocietyTargetObj = Struct.new(:id, :noun, :name) unless defined?(SocietyTargetObj)

  describe '.command' do
    it 'prefixes the short name, or sends the entry usage verb as is' do
      expect(described_class.command({ short_name: 'striking' }, 'sign of')).to eq('sign of striking')
      expect(described_class.command({ short_name: 'signal', usage: 'signal' }, 'sign of')).to eq('signal')
    end

    it 'appends a GameObj or id as #id and a String as given' do
      expect(described_class.command({ short_name: 'contact' }, 'sigil of', SocietyTargetObj.new('12345', 'orc', 'an orc'))).to eq('sigil of contact #12345')
      expect(described_class.command({ short_name: 'contact' }, 'sigil of', 12_345)).to eq('sigil of contact #12345')
      expect(described_class.command({ short_name: 'contact' }, 'sigil of', 'Dissonance')).to eq('sigil of contact Dissonance')
    end
  end

  describe 'the readers' do
    # The readers' [] resolves every lambda in an entry (durations and
    # costs read the level), so a level has to exist to build a command.
    # Inside the readers `Stats` is Lich::Gemstone::Stats once another
    # spec has loaded it, and the bare constant otherwise; stub both.
    before do
      stats = double('Stats', level: 20)
      stub_const('Stats', stats)
      stub_const('Lich::Gemstone::Stats', stats)
    end

    it 'build the same string use sends, by short or long name, nil for an unknown ability' do
      expect(Lich::Gemstone::Societies::CouncilOfLight.command('striking')).to eq('sign of striking')
      expect(Lich::Gemstone::Societies::CouncilOfLight.command('Sign of Signal')).to eq('signal')
      expect(Lich::Gemstone::Societies::GuardiansOfSunfist.command('contact', 'Dissonance')).to eq('sigil of contact Dissonance')
      expect(Lich::Gemstone::Societies::OrderOfVoln.command('holiness')).to eq('symbol of holiness')
      expect(Lich::Gemstone::Societies::OrderOfVoln.command("Kai's Smite", 42)).to eq('smite #42')
      expect(Lich::Gemstone::Societies::OrderOfVoln.command('no such symbol')).to be_nil
    end
  end
end
