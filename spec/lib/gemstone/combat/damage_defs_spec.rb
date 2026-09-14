# frozen_string_literal: true

require 'rspec'
require_relative '../../../../lib/gemstone/combat/defs/damage'

RSpec.describe Lich::Gemstone::Combat::Definitions::Damage do
  describe '.parse' do
    it 'parses the plain endroll damage line' do
      result = described_class.parse('   ... and hit for 50 points of damage!')
      expect(result).to eq(damage: 50)
    end

    # Chromatic Circle's element flavor line carries damage of its own,
    # generalized over the element (arcs/swirls/orbits) - the per-element
    # list missed "arcs", so lightning 502 kills undercounted and max_hp
    # lower bounds came out low.
    it 'parses every environmental verb variant' do
      [
        'The crackling lightning quickly arcs around the gnarp, causing 35 points of damage!',
        'The whirlwind quickly swirls around a kobold, causing 21 points of damage!',
        'The shifting stones quickly orbit a rolton, causing 9 points of damage!',
        'The ice shards quickly orbit the gnarp, causing 12 points of damage!'
      ].each do |line|
        result = described_class.parse(line)
        expect(result).not_to be_nil, "expected parse for: #{line}"
        expect(result[:damage]).to be > 0
      end
    end

    it 'returns nil for non-damage lines' do
      expect(described_class.parse('A kobold arrives.')).to be_nil
    end
  end
end
