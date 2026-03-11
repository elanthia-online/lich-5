# frozen_string_literal: true

require_relative '../../../spec_helper'

require_relative '../../../../lib/dragonrealms/drinfomon/drstats'

RSpec.describe Lich::DragonRealms::DRStats do
  include_context 'XMLData stubs'

  before(:each) do
    # Use public reset! API instead of manual attribute resets (SOLID: DIP).
    # The reset! method in production code resets all 18 attributes to defaults,
    # preventing test coupling to internal implementation details.
    described_class.reset!
  end

  describe 'attribute accessors' do
    describe '.race' do
      it 'returns nil by default' do
        expect(described_class.race).to be_nil
      end

      it 'can be set and retrieved' do
        described_class.race = 'Human'
        expect(described_class.race).to eq('Human')
      end
    end

    describe '.guild' do
      it 'returns nil by default' do
        expect(described_class.guild).to be_nil
      end

      it 'can be set and retrieved' do
        described_class.guild = 'Moon Mage'
        expect(described_class.guild).to eq('Moon Mage')
      end
    end

    describe '.gender' do
      it 'returns nil by default' do
        expect(described_class.gender).to be_nil
      end

      it 'can be set and retrieved' do
        described_class.gender = 'female'
        expect(described_class.gender).to eq('female')
      end
    end

    describe '.age' do
      it 'returns 0 by default' do
        expect(described_class.age).to eq(0)
      end

      it 'can be set and retrieved' do
        described_class.age = 25
        expect(described_class.age).to eq(25)
      end
    end

    describe '.circle' do
      it 'returns 0 by default' do
        expect(described_class.circle).to eq(0)
      end

      it 'can be set and retrieved' do
        described_class.circle = 150
        expect(described_class.circle).to eq(150)
      end
    end

    describe '.strength' do
      it 'returns 0 by default' do
        expect(described_class.strength).to eq(0)
      end

      it 'can be set and retrieved' do
        described_class.strength = 40
        expect(described_class.strength).to eq(40)
      end
    end

    describe '.stamina' do
      it 'returns 0 by default' do
        expect(described_class.stamina).to eq(0)
      end

      it 'can be set and retrieved' do
        described_class.stamina = 35
        expect(described_class.stamina).to eq(35)
      end
    end

    describe '.reflex' do
      it 'returns 0 by default' do
        expect(described_class.reflex).to eq(0)
      end

      it 'can be set and retrieved' do
        described_class.reflex = 45
        expect(described_class.reflex).to eq(45)
      end
    end

    describe '.agility' do
      it 'returns 0 by default' do
        expect(described_class.agility).to eq(0)
      end

      it 'can be set and retrieved' do
        described_class.agility = 50
        expect(described_class.agility).to eq(50)
      end
    end

    describe '.intelligence' do
      it 'returns 0 by default' do
        expect(described_class.intelligence).to eq(0)
      end

      it 'can be set and retrieved' do
        described_class.intelligence = 55
        expect(described_class.intelligence).to eq(55)
      end
    end

    describe '.wisdom' do
      it 'returns 0 by default' do
        expect(described_class.wisdom).to eq(0)
      end

      it 'can be set and retrieved' do
        described_class.wisdom = 38
        expect(described_class.wisdom).to eq(38)
      end
    end

    describe '.discipline' do
      it 'returns 0 by default' do
        expect(described_class.discipline).to eq(0)
      end

      it 'can be set and retrieved' do
        described_class.discipline = 42
        expect(described_class.discipline).to eq(42)
      end
    end

    describe '.charisma' do
      it 'returns 0 by default' do
        expect(described_class.charisma).to eq(0)
      end

      it 'can be set and retrieved' do
        described_class.charisma = 30
        expect(described_class.charisma).to eq(30)
      end
    end

    describe '.favors' do
      it 'returns 0 by default' do
        expect(described_class.favors).to eq(0)
      end

      it 'can be set and retrieved' do
        described_class.favors = 10
        expect(described_class.favors).to eq(10)
      end
    end

    describe '.tdps' do
      it 'returns 0 by default' do
        expect(described_class.tdps).to eq(0)
      end

      it 'can be set and retrieved' do
        described_class.tdps = 500
        expect(described_class.tdps).to eq(500)
      end
    end

    describe '.luck' do
      it 'returns 0 by default' do
        expect(described_class.luck).to eq(0)
      end

      it 'can be set and retrieved' do
        described_class.luck = 3
        expect(described_class.luck).to eq(3)
      end
    end

    describe '.encumbrance' do
      it 'returns nil by default' do
        expect(described_class.encumbrance).to be_nil
      end

      it 'can be set and retrieved' do
        described_class.encumbrance = 'Light Burden'
        expect(described_class.encumbrance).to eq('Light Burden')
      end
    end

    describe '.balance' do
      it 'returns 8 by default' do
        expect(described_class.balance).to eq(8)
      end

      it 'can be set and retrieved' do
        described_class.balance = 10
        expect(described_class.balance).to eq(10)
      end
    end
  end

  describe 'XMLData delegators' do
    describe '.name' do
      it 'returns XMLData.name' do
        expect(described_class.name).to eq('TestChar')
      end
    end

    describe '.health' do
      it 'returns XMLData.health' do
        expect(described_class.health).to eq(100)
      end
    end

    describe '.mana' do
      it 'returns XMLData.mana' do
        expect(described_class.mana).to eq(50)
      end
    end

    describe '.fatigue' do
      it 'returns XMLData.stamina' do
        expect(described_class.fatigue).to eq(75)
      end
    end

    describe '.spirit' do
      it 'returns XMLData.spirit' do
        expect(described_class.spirit).to eq(80)
      end
    end

    describe '.concentration' do
      it 'returns XMLData.concentration' do
        expect(described_class.concentration).to eq(90)
      end
    end
  end

  describe 'GUILD_MANA_TYPES constant' do
    it 'is frozen' do
      expect(described_class::GUILD_MANA_TYPES).to be_frozen
    end

    it 'maps Necromancer to arcane' do
      expect(described_class::GUILD_MANA_TYPES['Necromancer']).to eq('arcane')
    end

    it 'maps Barbarian to nil' do
      expect(described_class::GUILD_MANA_TYPES['Barbarian']).to be_nil
    end

    it 'maps Thief to nil' do
      expect(described_class::GUILD_MANA_TYPES['Thief']).to be_nil
    end

    it 'maps Moon Mage to lunar' do
      expect(described_class::GUILD_MANA_TYPES['Moon Mage']).to eq('lunar')
    end

    it 'maps Trader to lunar' do
      expect(described_class::GUILD_MANA_TYPES['Trader']).to eq('lunar')
    end

    it 'maps Warrior Mage to elemental' do
      expect(described_class::GUILD_MANA_TYPES['Warrior Mage']).to eq('elemental')
    end

    it 'maps Bard to elemental' do
      expect(described_class::GUILD_MANA_TYPES['Bard']).to eq('elemental')
    end

    it 'maps Cleric to holy' do
      expect(described_class::GUILD_MANA_TYPES['Cleric']).to eq('holy')
    end

    it 'maps Paladin to holy' do
      expect(described_class::GUILD_MANA_TYPES['Paladin']).to eq('holy')
    end

    it 'maps Empath to life' do
      expect(described_class::GUILD_MANA_TYPES['Empath']).to eq('life')
    end

    it 'maps Ranger to life' do
      expect(described_class::GUILD_MANA_TYPES['Ranger']).to eq('life')
    end
  end

  describe '.native_mana' do
    it 'returns nil when guild is nil' do
      described_class.guild = nil
      expect(described_class.native_mana).to be_nil
    end

    it 'returns nil for Barbarian' do
      described_class.guild = 'Barbarian'
      expect(described_class.native_mana).to be_nil
    end

    it 'returns nil for Thief' do
      described_class.guild = 'Thief'
      expect(described_class.native_mana).to be_nil
    end

    it 'returns arcane for Necromancer' do
      described_class.guild = 'Necromancer'
      expect(described_class.native_mana).to eq('arcane')
    end

    it 'returns lunar for Moon Mage' do
      described_class.guild = 'Moon Mage'
      expect(described_class.native_mana).to eq('lunar')
    end

    it 'returns lunar for Trader' do
      described_class.guild = 'Trader'
      expect(described_class.native_mana).to eq('lunar')
    end

    it 'returns elemental for Warrior Mage' do
      described_class.guild = 'Warrior Mage'
      expect(described_class.native_mana).to eq('elemental')
    end

    it 'returns elemental for Bard' do
      described_class.guild = 'Bard'
      expect(described_class.native_mana).to eq('elemental')
    end

    it 'returns holy for Cleric' do
      described_class.guild = 'Cleric'
      expect(described_class.native_mana).to eq('holy')
    end

    it 'returns holy for Paladin' do
      described_class.guild = 'Paladin'
      expect(described_class.native_mana).to eq('holy')
    end

    it 'returns life for Empath' do
      described_class.guild = 'Empath'
      expect(described_class.native_mana).to eq('life')
    end

    it 'returns life for Ranger' do
      described_class.guild = 'Ranger'
      expect(described_class.native_mana).to eq('life')
    end
  end

  describe '.serialize and .load_serialized=' do
    it 'serializes all 17 attributes in correct order' do
      described_class.race = 'Elf'
      described_class.guild = 'Moon Mage'
      described_class.gender = 'male'
      described_class.age = 30
      described_class.circle = 100
      described_class.strength = 40
      described_class.stamina = 35
      described_class.reflex = 45
      described_class.agility = 50
      described_class.intelligence = 55
      described_class.wisdom = 38
      described_class.discipline = 42
      described_class.charisma = 30
      described_class.favors = 10
      described_class.tdps = 500
      described_class.luck = 3
      described_class.encumbrance = 'Light Burden'

      serialized = described_class.serialize
      expect(serialized.length).to eq(17)
      expect(serialized[0]).to eq('Elf') # race
      expect(serialized[1]).to eq('Moon Mage') # guild
      expect(serialized[2]).to eq('male')          # gender
      expect(serialized[3]).to eq(30)              # age
      expect(serialized[4]).to eq(100)             # circle
      expect(serialized[5]).to eq(40)              # strength
      expect(serialized[6]).to eq(35)              # stamina
      expect(serialized[7]).to eq(45)              # reflex
      expect(serialized[8]).to eq(50)              # agility
      expect(serialized[9]).to eq(55)              # intelligence
      expect(serialized[10]).to eq(38)             # wisdom
      expect(serialized[11]).to eq(42)             # discipline
      expect(serialized[12]).to eq(30)             # charisma
      expect(serialized[13]).to eq(10)             # favors
      expect(serialized[14]).to eq(500)            # tdps
      expect(serialized[15]).to eq(3)              # luck
      expect(serialized[16]).to eq('Light Burden') # encumbrance
    end

    it 'deserializes all 17 attributes correctly (BUG FIX verification)' do
      # This test verifies the critical bug fix where load_serialized
      # was using array[5..12] (8 elements) but trying to assign 13 variables
      serialized = ['Elf', 'Moon Mage', 'male', 30, 100, 40, 35, 45, 50, 55, 38, 42, 30, 10, 500, 3, 'Light Burden']

      described_class.load_serialized = serialized

      expect(described_class.race).to eq('Elf')
      expect(described_class.guild).to eq('Moon Mage')
      expect(described_class.gender).to eq('male')
      expect(described_class.age).to eq(30)
      expect(described_class.circle).to eq(100)
      expect(described_class.strength).to eq(40)
      expect(described_class.stamina).to eq(35)
      expect(described_class.reflex).to eq(45)
      expect(described_class.agility).to eq(50)
      expect(described_class.intelligence).to eq(55)
      expect(described_class.wisdom).to eq(38)
      expect(described_class.discipline).to eq(42)
      expect(described_class.charisma).to eq(30)
      expect(described_class.favors).to eq(10)
      expect(described_class.tdps).to eq(500)
      expect(described_class.luck).to eq(3)
      expect(described_class.encumbrance).to eq('Light Burden')
    end

    it 'handles nil array gracefully' do
      # Should not raise
      expect { described_class.load_serialized = nil }.not_to raise_error
    end

    it 'handles empty array gracefully' do
      # Should not raise
      expect { described_class.load_serialized = [] }.not_to raise_error
    end

    it 'round-trips serialize/load_serialized correctly' do
      described_class.race = 'Human'
      described_class.guild = 'Ranger'
      described_class.gender = 'female'
      described_class.age = 45
      described_class.circle = 75
      described_class.strength = 35
      described_class.stamina = 40
      described_class.reflex = 50
      described_class.agility = 48
      described_class.intelligence = 42
      described_class.wisdom = 45
      described_class.discipline = 50
      described_class.charisma = 35
      described_class.favors = 5
      described_class.tdps = 200
      described_class.luck = 1
      described_class.encumbrance = 'None'

      serialized = described_class.serialize

      # Reset all values
      described_class.race = nil
      described_class.guild = nil
      described_class.gender = nil
      described_class.age = 0
      described_class.circle = 0
      described_class.strength = 0
      described_class.stamina = 0
      described_class.reflex = 0
      described_class.agility = 0
      described_class.intelligence = 0
      described_class.wisdom = 0
      described_class.discipline = 0
      described_class.charisma = 0
      described_class.favors = 0
      described_class.tdps = 0
      described_class.luck = 0
      described_class.encumbrance = nil

      # Load serialized data
      described_class.load_serialized = serialized

      # Verify all values restored correctly
      expect(described_class.race).to eq('Human')
      expect(described_class.guild).to eq('Ranger')
      expect(described_class.gender).to eq('female')
      expect(described_class.age).to eq(45)
      expect(described_class.circle).to eq(75)
      expect(described_class.strength).to eq(35)
      expect(described_class.stamina).to eq(40)
      expect(described_class.reflex).to eq(50)
      expect(described_class.agility).to eq(48)
      expect(described_class.intelligence).to eq(42)
      expect(described_class.wisdom).to eq(45)
      expect(described_class.discipline).to eq(50)
      expect(described_class.charisma).to eq(35)
      expect(described_class.favors).to eq(5)
      expect(described_class.tdps).to eq(200)
      expect(described_class.luck).to eq(1)
      expect(described_class.encumbrance).to eq('None')
    end
  end

  describe 'guild predicate methods' do
    include_examples 'guild predicate', 'Barbarian', :barbarian?
    include_examples 'guild predicate', 'Bard', :bard?
    include_examples 'guild predicate', 'Cleric', :cleric?
    include_examples 'guild predicate', 'Commoner', :commoner?
    include_examples 'guild predicate', 'Empath', :empath?
    include_examples 'guild predicate', 'Moon Mage', :moon_mage?
    include_examples 'guild predicate', 'Necromancer', :necromancer?
    include_examples 'guild predicate', 'Paladin', :paladin?
    include_examples 'guild predicate', 'Ranger', :ranger?
    include_examples 'guild predicate', 'Thief', :thief?
    include_examples 'guild predicate', 'Trader', :trader?
    include_examples 'guild predicate', 'Warrior Mage', :warrior_mage?
  end
end
