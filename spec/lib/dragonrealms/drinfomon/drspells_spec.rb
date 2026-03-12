# frozen_string_literal: true

require_relative '../../../spec_helper'

# NOTE: We use the DRSpells mock from spec_helper.rb which provides all
# necessary methods for testing. The mock delegates active_spells to XMLData
# just like production code.

RSpec.describe Lich::DragonRealms::DRSpells do
  include_context 'DRSpells XMLData stubs'

  before(:each) do
    described_class.reset!
  end

  describe 'XMLData delegators' do
    describe '.active_spells' do
      it 'returns XMLData.dr_active_spells' do
        expect(described_class.active_spells).to eq({ 'Protection' => 120, 'Shield' => 60 })
      end
    end

    describe '.slivers' do
      it 'returns XMLData.dr_active_spells_slivers' do
        expect(described_class.slivers).to eq(3)
      end
    end

    describe '.stellar_percentage' do
      it 'returns XMLData.dr_active_spells_stellar_percentage' do
        expect(described_class.stellar_percentage).to eq(45)
      end
    end
  end

  describe 'spell knowledge storage' do
    describe '.known_spells' do
      it 'returns empty hash by default' do
        expect(described_class.known_spells).to eq({})
      end

      it 'can store spell knowledge' do
        described_class.known_spells['Heal'] = true
        expect(described_class.known_spells['Heal']).to be true
      end
    end

    describe '.known_feats' do
      it 'returns empty hash by default' do
        expect(described_class.known_feats).to eq({})
      end

      it 'can store feat knowledge' do
        described_class.known_feats['Combat Focus'] = true
        expect(described_class.known_feats['Combat Focus']).to be true
      end
    end
  end

  describe 'spellbook format' do
    describe '.spellbook_format' do
      it 'returns nil by default' do
        expect(described_class.spellbook_format).to be_nil
      end

      it 'can be set to column-formatted' do
        described_class.spellbook_format = 'column-formatted'
        expect(described_class.spellbook_format).to eq('column-formatted')
      end

      it 'can be set to non-column' do
        described_class.spellbook_format = 'non-column'
        expect(described_class.spellbook_format).to eq('non-column')
      end
    end
  end

  describe 'spell parsing state flags' do
    describe '.grabbing_known_spells' do
      it 'returns false by default' do
        expect(described_class.grabbing_known_spells).to be false
      end

      it 'can be set to true' do
        described_class.grabbing_known_spells = true
        expect(described_class.grabbing_known_spells).to be true
      end

      it 'can be set back to false' do
        described_class.grabbing_known_spells = true
        described_class.grabbing_known_spells = false
        expect(described_class.grabbing_known_spells).to be false
      end
    end

    describe '.check_known_barbarian_abilities' do
      it 'returns false by default' do
        expect(described_class.check_known_barbarian_abilities).to be false
      end

      it 'can be set to true' do
        described_class.check_known_barbarian_abilities = true
        expect(described_class.check_known_barbarian_abilities).to be true
      end
    end

    describe '.grabbing_known_khri' do
      it 'returns false by default' do
        expect(described_class.grabbing_known_khri).to be false
      end

      it 'can be set to true' do
        described_class.grabbing_known_khri = true
        expect(described_class.grabbing_known_khri).to be true
      end
    end
  end
end
