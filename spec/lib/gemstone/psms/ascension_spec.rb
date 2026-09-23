# frozen_string_literal: true

require_relative 'psm_spec_helper'

RSpec.describe Lich::Gemstone::Ascension do
  include_context 'psm game state'

  let(:ascension) { described_class }
  let(:lookups) { ascension.ascension_lookups }

  it 'lists each ascension ability once, free, by a normalized long name' do
    expect(lookups).not_to be_empty
    expect(lookups.map { |l| l[:short_name] }).to eq(lookups.map { |l| l[:short_name] }.uniq)
    expect(lookups.map { |l| l[:long_name] }).to eq(lookups.map { |l| l[:long_name] }.uniq)
    lookups.each do |l|
      expect(Lich::Gemstone::PSMS.name_normal(l[:long_name])).to eq(l[:long_name])
      expect(l[:cost]).to eq(stamina: 0)
    end
  end

  it 'reads ranks from Infomon by long name, short name and getter' do
    ranks('ascension.regenstamina' => 4)
    expect(ascension['stamina_regeneration']).to eq(4)
    expect(ascension['regenstamina']).to eq(4)
    expect(ascension.stamina_regeneration).to eq(4)
    expect(ascension.regenstamina).to eq(4)
    expect(ascension.known?('Stamina Regeneration')).to be(true)
  end

  it 'is available once known, while the character is not overexerted' do
    ranks('ascension.regenstamina' => 1, 'ascension.regenmana' => 0)
    expect(ascension.available?('regenstamina')).to be(true)
    expect(ascension.available?('regenmana')).to be(false)
    effects('Debuffs', 'Overexerted')
    expect(ascension.available?('regenstamina')).to be(false)
  end

  it 'rejects an unknown ability' do
    expect { ascension['flying'] }.to raise_error(ArgumentError, /The referenced Ascension skill flying is invalid/)
  end
end
