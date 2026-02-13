# frozen_string_literal: true

require 'rspec'

# Define XMLData module if not already defined
module XMLData
end unless defined?(XMLData)

# Add required methods to XMLData (may already exist from spec_helper)
unless XMLData.respond_to?(:dr_active_spells)
  XMLData.define_singleton_method(:dr_active_spells) { { 'Protection' => 120, 'Shield' => 60 } }
end
unless XMLData.respond_to?(:dr_active_spells_slivers)
  XMLData.define_singleton_method(:dr_active_spells_slivers) { 3 }
end
unless XMLData.respond_to?(:dr_active_spells_stellar_percentage)
  XMLData.define_singleton_method(:dr_active_spells_stellar_percentage) { 45 }
end

require_relative '../../../../lib/dragonrealms/drinfomon/drspells'

RSpec.describe Lich::DragonRealms::DRSpells do
  let(:described_module) { Lich::DragonRealms::DRSpells }

  before(:each) do
    # Reset class variables
    described_module.class_variable_set(:@@known_spells, {})
    described_module.class_variable_set(:@@known_feats, {})
    described_module.class_variable_set(:@@spellbook_format, nil)
    described_module.class_variable_set(:@@grabbing_known_spells, false)
    described_module.class_variable_set(:@@grabbing_known_barbarian_abilities, false)
    described_module.class_variable_set(:@@grabbing_known_khri, false)
  end

  describe 'XMLData delegators' do
    describe '.active_spells' do
      it 'returns XMLData.dr_active_spells' do
        expect(described_module.active_spells).to eq({ 'Protection' => 120, 'Shield' => 60 })
      end
    end

    describe '.slivers' do
      it 'returns XMLData.dr_active_spells_slivers' do
        expect(described_module.slivers).to eq(3)
      end
    end

    describe '.stellar_percentage' do
      it 'returns XMLData.dr_active_spells_stellar_percentage' do
        expect(described_module.stellar_percentage).to eq(45)
      end
    end
  end

  describe 'spell knowledge storage' do
    describe '.known_spells' do
      it 'returns empty hash by default' do
        expect(described_module.known_spells).to eq({})
      end

      it 'can store spell knowledge' do
        described_module.known_spells['Heal'] = true
        expect(described_module.known_spells['Heal']).to be true
      end
    end

    describe '.known_feats' do
      it 'returns empty hash by default' do
        expect(described_module.known_feats).to eq({})
      end

      it 'can store feat knowledge' do
        described_module.known_feats['Combat Focus'] = true
        expect(described_module.known_feats['Combat Focus']).to be true
      end
    end
  end

  describe 'spellbook format' do
    describe '.spellbook_format' do
      it 'returns nil by default' do
        expect(described_module.spellbook_format).to be_nil
      end

      it 'can be set to column-formatted' do
        described_module.spellbook_format = 'column-formatted'
        expect(described_module.spellbook_format).to eq('column-formatted')
      end

      it 'can be set to non-column' do
        described_module.spellbook_format = 'non-column'
        expect(described_module.spellbook_format).to eq('non-column')
      end
    end
  end

  describe 'spell parsing state flags' do
    describe '.grabbing_known_spells' do
      it 'returns false by default' do
        expect(described_module.grabbing_known_spells).to be false
      end

      it 'can be set to true' do
        described_module.grabbing_known_spells = true
        expect(described_module.grabbing_known_spells).to be true
      end

      it 'can be set back to false' do
        described_module.grabbing_known_spells = true
        described_module.grabbing_known_spells = false
        expect(described_module.grabbing_known_spells).to be false
      end
    end

    describe '.check_known_barbarian_abilities' do
      it 'returns false by default' do
        expect(described_module.check_known_barbarian_abilities).to be false
      end

      it 'can be set to true' do
        described_module.check_known_barbarian_abilities = true
        expect(described_module.check_known_barbarian_abilities).to be true
      end
    end

    describe '.grabbing_known_khri' do
      it 'returns false by default' do
        expect(described_module.grabbing_known_khri).to be false
      end

      it 'can be set to true' do
        described_module.grabbing_known_khri = true
        expect(described_module.grabbing_known_khri).to be true
      end
    end
  end
end
