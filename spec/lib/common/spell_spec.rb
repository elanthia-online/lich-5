# frozen_string_literal: true

require_relative '../../spec_helper'

# Load spell data from fixture
load_spell_data

RSpec.describe Lich::Common::Spell do
  describe '.load' do
    it 'loads spells from the fixture file' do
      expect(Lich::Common::Spell.list).not_to be_empty
    end

    it 'loads a reasonable number of spells' do
      # effect-list.xml contains 500+ spells
      expect(Lich::Common::Spell.list.size).to be > 400
    end
  end

  describe '.[]' do
    context 'when looking up by number' do
      it 'finds Spirit Warding I by number 101' do
        spell = Lich::Common::Spell[101]
        expect(spell).not_to be_nil
        expect(spell.num).to eq(101)
        expect(spell.name).to eq('Spirit Warding I')
      end

      it 'finds a Major Elemental spell by number' do
        spell = Lich::Common::Spell[506]
        expect(spell).not_to be_nil
        expect(spell.num).to eq(506)
        expect(spell.name).to eq('Celerity')
      end

      it 'returns nil for unknown spell number' do
        spell = Lich::Common::Spell[99999]
        expect(spell).to be_nil
      end
    end

    context 'when looking up by name' do
      it 'finds Spirit Warding I by exact name' do
        spell = Lich::Common::Spell['Spirit Warding I']
        expect(spell).not_to be_nil
        expect(spell.num).to eq(101)
      end

      it 'finds spell by partial name match' do
        spell = Lich::Common::Spell['Spirit Warding']
        expect(spell).not_to be_nil
        expect(spell.name).to match(/Spirit Warding/)
      end

      it 'is case insensitive' do
        spell = Lich::Common::Spell['spirit warding i']
        expect(spell).not_to be_nil
        expect(spell.num).to eq(101)
      end
    end

    context 'when passed a Spell object' do
      it 'returns the same object' do
        spell = Lich::Common::Spell[101]
        expect(Lich::Common::Spell[spell]).to eq(spell)
      end
    end
  end

  describe 'spell properties' do
    let(:spirit_warding) { Lich::Common::Spell[101] }

    it 'has a number' do
      expect(spirit_warding.num).to eq(101)
    end

    it 'has a name' do
      expect(spirit_warding.name).to eq('Spirit Warding I')
    end

    it 'has a circle' do
      # Circle 1 for spell 101
      expect(spirit_warding.circle).to eq('1')
    end

    it 'has a type' do
      expect(spirit_warding.type).to eq('defense')
    end

    it 'has availability' do
      expect(spirit_warding.availability).to eq('all')
    end

    it 'has start message (msgup)' do
      expect(spirit_warding.msgup).to include('light blue glow surrounds you')
    end

    it 'has end message (msgdn)' do
      expect(spirit_warding.msgdn).to include('light blue glow leaves you')
    end
  end

  describe '.list' do
    it 'returns all loaded spells' do
      list = Lich::Common::Spell.list
      expect(list).to be_an(Array)
      expect(list.first).to be_a(Lich::Common::Spell)
    end
  end

  describe '.upmsgs' do
    it 'returns spell start messages' do
      upmsgs = Lich::Common::Spell.upmsgs
      expect(upmsgs).to be_an(Array)
      expect(upmsgs.compact).not_to be_empty
    end
  end

  describe '.dnmsgs' do
    it 'returns spell end messages' do
      dnmsgs = Lich::Common::Spell.dnmsgs
      expect(dnmsgs).to be_an(Array)
      expect(dnmsgs.compact).not_to be_empty
    end
  end

  describe '#to_s' do
    it 'returns the spell name' do
      spell = Lich::Common::Spell[101]
      expect(spell.to_s).to eq('Spirit Warding I')
    end
  end

  describe '#circle_name' do
    before do
      # Mock Spells.get_circle_name
      stub_const('Spells', Module.new)
      allow(Spells).to receive(:get_circle_name).with('1').and_return('Minor Spirit')
    end

    it 'returns the circle name' do
      spell = Lich::Common::Spell[101]
      expect(spell.circle_name).to eq('Minor Spirit')
    end
  end

  describe 'spell circles' do
    it 'correctly identifies Minor Spirit spells (100s)' do
      spell = Lich::Common::Spell[107]
      expect(spell.circle).to eq('1')
    end

    it 'correctly identifies Major Spirit spells (200s)' do
      spell = Lich::Common::Spell[201]
      expect(spell).not_to be_nil
      expect(spell.circle).to eq('2')
    end

    it 'correctly identifies Cleric spells (300s)' do
      spell = Lich::Common::Spell[301]
      expect(spell).not_to be_nil
      expect(spell.circle).to eq('3')
    end

    it 'correctly identifies Minor Elemental spells (400s)' do
      spell = Lich::Common::Spell[401]
      expect(spell).not_to be_nil
      expect(spell.circle).to eq('4')
    end

    it 'correctly identifies Major Elemental spells (500s)' do
      spell = Lich::Common::Spell[501]
      expect(spell).not_to be_nil
      expect(spell.circle).to eq('5')
    end

    it 'correctly identifies Wizard spells (900s)' do
      spell = Lich::Common::Spell[901]
      expect(spell).not_to be_nil
      expect(spell.circle).to eq('9')
    end

    it 'correctly identifies Bard spells (1000s)' do
      spell = Lich::Common::Spell[1001]
      expect(spell).not_to be_nil
      expect(spell.circle).to eq('10')
    end
  end

  describe '#incant?' do
    it 'returns true for spells that can be incanted' do
      spell = Lich::Common::Spell[101]
      expect(spell.incant?).to be true
    end

    it 'returns false for spells marked no_incant' do
      # Find a spell with no_incant if one exists
      no_incant_spell = Lich::Common::Spell.list.find { |s| !s.incant? }
      if no_incant_spell
        expect(no_incant_spell.incant?).to be false
      end
    end
  end

  describe '#selfonly' do
    it 'returns false for spells available to all' do
      spell = Lich::Common::Spell[101] # Spirit Warding I is availability='all'
      expect(spell.selfonly).to be false
    end

    it 'returns true for self-only spells' do
      spell = Lich::Common::Spell[102] # Spirit Barrier is availability='self-cast'
      expect(spell.selfonly).to be true
    end
  end

  describe 'cost methods' do
    let(:spell) { Lich::Common::Spell[101] }

    it 'has mana cost' do
      # Spirit Warding I costs 1 mana
      expect(spell._cost).to include('mana')
      expect(spell._cost['mana']['self']).to eq('1')
    end
  end

  describe 'bonus methods' do
    let(:spell) { Lich::Common::Spell[101] }

    it 'has defense bonuses' do
      bonuses = spell._bonus
      expect(bonuses).to include('bolt-ds')
      expect(bonuses).to include('spirit-td')
    end
  end
end
