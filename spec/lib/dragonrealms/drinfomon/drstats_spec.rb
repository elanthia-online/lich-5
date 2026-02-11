# frozen_string_literal: true

require 'rspec'

# Define XMLData module if not already defined
module XMLData
end unless defined?(XMLData)

# Add required methods to XMLData (may already exist from other specs)
# Note: :name must always be defined because Module#name exists but returns the wrong value
XMLData.define_singleton_method(:name) { 'TestChar' }
XMLData.define_singleton_method(:health) { 100 } unless XMLData.respond_to?(:health)
XMLData.define_singleton_method(:mana) { 50 } unless XMLData.respond_to?(:mana)
XMLData.define_singleton_method(:stamina) { 75 } unless XMLData.respond_to?(:stamina)
XMLData.define_singleton_method(:spirit) { 80 } unless XMLData.respond_to?(:spirit)
XMLData.define_singleton_method(:concentration) { 90 } unless XMLData.respond_to?(:concentration)

require_relative '../../../../lib/dragonrealms/drinfomon/drstats'

RSpec.describe Lich::DragonRealms::DRStats do
  let(:described_module) { Lich::DragonRealms::DRStats }

  before(:each) do
    # Reset all class variables to defaults before each test
    described_module.race = nil
    described_module.guild = nil
    described_module.gender = nil
    described_module.age = 0
    described_module.circle = 0
    described_module.strength = 0
    described_module.stamina = 0
    described_module.reflex = 0
    described_module.agility = 0
    described_module.intelligence = 0
    described_module.wisdom = 0
    described_module.discipline = 0
    described_module.charisma = 0
    described_module.favors = 0
    described_module.tdps = 0
    described_module.luck = 0
    described_module.encumbrance = nil
    described_module.balance = 8
  end

  describe 'attribute accessors' do
    describe '.race' do
      it 'returns nil by default' do
        expect(described_module.race).to be_nil
      end

      it 'can be set and retrieved' do
        described_module.race = 'Human'
        expect(described_module.race).to eq('Human')
      end
    end

    describe '.guild' do
      it 'returns nil by default' do
        expect(described_module.guild).to be_nil
      end

      it 'can be set and retrieved' do
        described_module.guild = 'Moon Mage'
        expect(described_module.guild).to eq('Moon Mage')
      end
    end

    describe '.gender' do
      it 'returns nil by default' do
        expect(described_module.gender).to be_nil
      end

      it 'can be set and retrieved' do
        described_module.gender = 'female'
        expect(described_module.gender).to eq('female')
      end
    end

    describe '.age' do
      it 'returns 0 by default' do
        expect(described_module.age).to eq(0)
      end

      it 'can be set and retrieved' do
        described_module.age = 25
        expect(described_module.age).to eq(25)
      end
    end

    describe '.circle' do
      it 'returns 0 by default' do
        expect(described_module.circle).to eq(0)
      end

      it 'can be set and retrieved' do
        described_module.circle = 150
        expect(described_module.circle).to eq(150)
      end
    end

    describe '.strength' do
      it 'returns 0 by default' do
        expect(described_module.strength).to eq(0)
      end

      it 'can be set and retrieved' do
        described_module.strength = 40
        expect(described_module.strength).to eq(40)
      end
    end

    describe '.stamina' do
      it 'returns 0 by default' do
        expect(described_module.stamina).to eq(0)
      end

      it 'can be set and retrieved' do
        described_module.stamina = 35
        expect(described_module.stamina).to eq(35)
      end
    end

    describe '.reflex' do
      it 'returns 0 by default' do
        expect(described_module.reflex).to eq(0)
      end

      it 'can be set and retrieved' do
        described_module.reflex = 45
        expect(described_module.reflex).to eq(45)
      end
    end

    describe '.agility' do
      it 'returns 0 by default' do
        expect(described_module.agility).to eq(0)
      end

      it 'can be set and retrieved' do
        described_module.agility = 50
        expect(described_module.agility).to eq(50)
      end
    end

    describe '.intelligence' do
      it 'returns 0 by default' do
        expect(described_module.intelligence).to eq(0)
      end

      it 'can be set and retrieved' do
        described_module.intelligence = 55
        expect(described_module.intelligence).to eq(55)
      end
    end

    describe '.wisdom' do
      it 'returns 0 by default' do
        expect(described_module.wisdom).to eq(0)
      end

      it 'can be set and retrieved' do
        described_module.wisdom = 38
        expect(described_module.wisdom).to eq(38)
      end
    end

    describe '.discipline' do
      it 'returns 0 by default' do
        expect(described_module.discipline).to eq(0)
      end

      it 'can be set and retrieved' do
        described_module.discipline = 42
        expect(described_module.discipline).to eq(42)
      end
    end

    describe '.charisma' do
      it 'returns 0 by default' do
        expect(described_module.charisma).to eq(0)
      end

      it 'can be set and retrieved' do
        described_module.charisma = 30
        expect(described_module.charisma).to eq(30)
      end
    end

    describe '.favors' do
      it 'returns 0 by default' do
        expect(described_module.favors).to eq(0)
      end

      it 'can be set and retrieved' do
        described_module.favors = 10
        expect(described_module.favors).to eq(10)
      end
    end

    describe '.tdps' do
      it 'returns 0 by default' do
        expect(described_module.tdps).to eq(0)
      end

      it 'can be set and retrieved' do
        described_module.tdps = 500
        expect(described_module.tdps).to eq(500)
      end
    end

    describe '.luck' do
      it 'returns 0 by default' do
        expect(described_module.luck).to eq(0)
      end

      it 'can be set and retrieved' do
        described_module.luck = 3
        expect(described_module.luck).to eq(3)
      end
    end

    describe '.encumbrance' do
      it 'returns nil by default' do
        expect(described_module.encumbrance).to be_nil
      end

      it 'can be set and retrieved' do
        described_module.encumbrance = 'Light Burden'
        expect(described_module.encumbrance).to eq('Light Burden')
      end
    end

    describe '.balance' do
      it 'returns 8 by default' do
        expect(described_module.balance).to eq(8)
      end

      it 'can be set and retrieved' do
        described_module.balance = 10
        expect(described_module.balance).to eq(10)
      end
    end
  end

  describe 'XMLData delegators' do
    describe '.name' do
      it 'returns XMLData.name' do
        expect(described_module.name).to eq('TestChar')
      end
    end

    describe '.health' do
      it 'returns XMLData.health' do
        expect(described_module.health).to eq(100)
      end
    end

    describe '.mana' do
      it 'returns XMLData.mana' do
        expect(described_module.mana).to eq(50)
      end
    end

    describe '.fatigue' do
      it 'returns XMLData.stamina' do
        expect(described_module.fatigue).to eq(75)
      end
    end

    describe '.spirit' do
      it 'returns XMLData.spirit' do
        expect(described_module.spirit).to eq(80)
      end
    end

    describe '.concentration' do
      it 'returns XMLData.concentration' do
        expect(described_module.concentration).to eq(90)
      end
    end
  end

  describe 'GUILD_MANA_TYPES constant' do
    it 'is frozen' do
      expect(described_module::GUILD_MANA_TYPES).to be_frozen
    end

    it 'maps Necromancer to arcane' do
      expect(described_module::GUILD_MANA_TYPES['Necromancer']).to eq('arcane')
    end

    it 'maps Barbarian to nil' do
      expect(described_module::GUILD_MANA_TYPES['Barbarian']).to be_nil
    end

    it 'maps Thief to nil' do
      expect(described_module::GUILD_MANA_TYPES['Thief']).to be_nil
    end

    it 'maps Moon Mage to lunar' do
      expect(described_module::GUILD_MANA_TYPES['Moon Mage']).to eq('lunar')
    end

    it 'maps Trader to lunar' do
      expect(described_module::GUILD_MANA_TYPES['Trader']).to eq('lunar')
    end

    it 'maps Warrior Mage to elemental' do
      expect(described_module::GUILD_MANA_TYPES['Warrior Mage']).to eq('elemental')
    end

    it 'maps Bard to elemental' do
      expect(described_module::GUILD_MANA_TYPES['Bard']).to eq('elemental')
    end

    it 'maps Cleric to holy' do
      expect(described_module::GUILD_MANA_TYPES['Cleric']).to eq('holy')
    end

    it 'maps Paladin to holy' do
      expect(described_module::GUILD_MANA_TYPES['Paladin']).to eq('holy')
    end

    it 'maps Empath to life' do
      expect(described_module::GUILD_MANA_TYPES['Empath']).to eq('life')
    end

    it 'maps Ranger to life' do
      expect(described_module::GUILD_MANA_TYPES['Ranger']).to eq('life')
    end
  end

  describe '.native_mana' do
    it 'returns nil when guild is nil' do
      described_module.guild = nil
      expect(described_module.native_mana).to be_nil
    end

    it 'returns nil for Barbarian' do
      described_module.guild = 'Barbarian'
      expect(described_module.native_mana).to be_nil
    end

    it 'returns nil for Thief' do
      described_module.guild = 'Thief'
      expect(described_module.native_mana).to be_nil
    end

    it 'returns arcane for Necromancer' do
      described_module.guild = 'Necromancer'
      expect(described_module.native_mana).to eq('arcane')
    end

    it 'returns lunar for Moon Mage' do
      described_module.guild = 'Moon Mage'
      expect(described_module.native_mana).to eq('lunar')
    end

    it 'returns lunar for Trader' do
      described_module.guild = 'Trader'
      expect(described_module.native_mana).to eq('lunar')
    end

    it 'returns elemental for Warrior Mage' do
      described_module.guild = 'Warrior Mage'
      expect(described_module.native_mana).to eq('elemental')
    end

    it 'returns elemental for Bard' do
      described_module.guild = 'Bard'
      expect(described_module.native_mana).to eq('elemental')
    end

    it 'returns holy for Cleric' do
      described_module.guild = 'Cleric'
      expect(described_module.native_mana).to eq('holy')
    end

    it 'returns holy for Paladin' do
      described_module.guild = 'Paladin'
      expect(described_module.native_mana).to eq('holy')
    end

    it 'returns life for Empath' do
      described_module.guild = 'Empath'
      expect(described_module.native_mana).to eq('life')
    end

    it 'returns life for Ranger' do
      described_module.guild = 'Ranger'
      expect(described_module.native_mana).to eq('life')
    end
  end

  describe '.serialize and .load_serialized=' do
    it 'serializes all 17 attributes in correct order' do
      described_module.race = 'Elf'
      described_module.guild = 'Moon Mage'
      described_module.gender = 'male'
      described_module.age = 30
      described_module.circle = 100
      described_module.strength = 40
      described_module.stamina = 35
      described_module.reflex = 45
      described_module.agility = 50
      described_module.intelligence = 55
      described_module.wisdom = 38
      described_module.discipline = 42
      described_module.charisma = 30
      described_module.favors = 10
      described_module.tdps = 500
      described_module.luck = 3
      described_module.encumbrance = 'Light Burden'

      serialized = described_module.serialize
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

      described_module.load_serialized = serialized

      expect(described_module.race).to eq('Elf')
      expect(described_module.guild).to eq('Moon Mage')
      expect(described_module.gender).to eq('male')
      expect(described_module.age).to eq(30)
      expect(described_module.circle).to eq(100)
      expect(described_module.strength).to eq(40)
      expect(described_module.stamina).to eq(35)
      expect(described_module.reflex).to eq(45)
      expect(described_module.agility).to eq(50)
      expect(described_module.intelligence).to eq(55)
      expect(described_module.wisdom).to eq(38)
      expect(described_module.discipline).to eq(42)
      expect(described_module.charisma).to eq(30)
      expect(described_module.favors).to eq(10)
      expect(described_module.tdps).to eq(500)
      expect(described_module.luck).to eq(3)
      expect(described_module.encumbrance).to eq('Light Burden')
    end

    it 'handles nil array gracefully' do
      # Should not raise
      expect { described_module.load_serialized = nil }.not_to raise_error
    end

    it 'handles empty array gracefully' do
      # Should not raise
      expect { described_module.load_serialized = [] }.not_to raise_error
    end

    it 'round-trips serialize/load_serialized correctly' do
      described_module.race = 'Human'
      described_module.guild = 'Ranger'
      described_module.gender = 'female'
      described_module.age = 45
      described_module.circle = 75
      described_module.strength = 35
      described_module.stamina = 40
      described_module.reflex = 50
      described_module.agility = 48
      described_module.intelligence = 42
      described_module.wisdom = 45
      described_module.discipline = 50
      described_module.charisma = 35
      described_module.favors = 5
      described_module.tdps = 200
      described_module.luck = 1
      described_module.encumbrance = 'None'

      serialized = described_module.serialize

      # Reset all values
      described_module.race = nil
      described_module.guild = nil
      described_module.gender = nil
      described_module.age = 0
      described_module.circle = 0
      described_module.strength = 0
      described_module.stamina = 0
      described_module.reflex = 0
      described_module.agility = 0
      described_module.intelligence = 0
      described_module.wisdom = 0
      described_module.discipline = 0
      described_module.charisma = 0
      described_module.favors = 0
      described_module.tdps = 0
      described_module.luck = 0
      described_module.encumbrance = nil

      # Load serialized data
      described_module.load_serialized = serialized

      # Verify all values restored correctly
      expect(described_module.race).to eq('Human')
      expect(described_module.guild).to eq('Ranger')
      expect(described_module.gender).to eq('female')
      expect(described_module.age).to eq(45)
      expect(described_module.circle).to eq(75)
      expect(described_module.strength).to eq(35)
      expect(described_module.stamina).to eq(40)
      expect(described_module.reflex).to eq(50)
      expect(described_module.agility).to eq(48)
      expect(described_module.intelligence).to eq(42)
      expect(described_module.wisdom).to eq(45)
      expect(described_module.discipline).to eq(50)
      expect(described_module.charisma).to eq(35)
      expect(described_module.favors).to eq(5)
      expect(described_module.tdps).to eq(200)
      expect(described_module.luck).to eq(1)
      expect(described_module.encumbrance).to eq('None')
    end
  end

  describe 'guild predicate methods' do
    describe '.barbarian?' do
      it 'returns true when guild is Barbarian' do
        described_module.guild = 'Barbarian'
        expect(described_module.barbarian?).to be true
      end

      it 'returns false when guild is not Barbarian' do
        described_module.guild = 'Moon Mage'
        expect(described_module.barbarian?).to be false
      end

      it 'returns false when guild is nil' do
        described_module.guild = nil
        expect(described_module.barbarian?).to be false
      end
    end

    describe '.bard?' do
      it 'returns true when guild is Bard' do
        described_module.guild = 'Bard'
        expect(described_module.bard?).to be true
      end

      it 'returns false when guild is not Bard' do
        described_module.guild = 'Ranger'
        expect(described_module.bard?).to be false
      end
    end

    describe '.cleric?' do
      it 'returns true when guild is Cleric' do
        described_module.guild = 'Cleric'
        expect(described_module.cleric?).to be true
      end

      it 'returns false when guild is not Cleric' do
        described_module.guild = 'Empath'
        expect(described_module.cleric?).to be false
      end
    end

    describe '.commoner?' do
      it 'returns true when guild is Commoner' do
        described_module.guild = 'Commoner'
        expect(described_module.commoner?).to be true
      end

      it 'returns false when guild is not Commoner' do
        described_module.guild = 'Paladin'
        expect(described_module.commoner?).to be false
      end
    end

    describe '.empath?' do
      it 'returns true when guild is Empath' do
        described_module.guild = 'Empath'
        expect(described_module.empath?).to be true
      end

      it 'returns false when guild is not Empath' do
        described_module.guild = 'Thief'
        expect(described_module.empath?).to be false
      end
    end

    describe '.moon_mage?' do
      it 'returns true when guild is Moon Mage' do
        described_module.guild = 'Moon Mage'
        expect(described_module.moon_mage?).to be true
      end

      it 'returns false when guild is not Moon Mage' do
        described_module.guild = 'Trader'
        expect(described_module.moon_mage?).to be false
      end
    end

    describe '.necromancer?' do
      it 'returns true when guild is Necromancer' do
        described_module.guild = 'Necromancer'
        expect(described_module.necromancer?).to be true
      end

      it 'returns false when guild is not Necromancer' do
        described_module.guild = 'Warrior Mage'
        expect(described_module.necromancer?).to be false
      end
    end

    describe '.paladin?' do
      it 'returns true when guild is Paladin' do
        described_module.guild = 'Paladin'
        expect(described_module.paladin?).to be true
      end

      it 'returns false when guild is not Paladin' do
        described_module.guild = 'Cleric'
        expect(described_module.paladin?).to be false
      end
    end

    describe '.ranger?' do
      it 'returns true when guild is Ranger' do
        described_module.guild = 'Ranger'
        expect(described_module.ranger?).to be true
      end

      it 'returns false when guild is not Ranger' do
        described_module.guild = 'Empath'
        expect(described_module.ranger?).to be false
      end
    end

    describe '.thief?' do
      it 'returns true when guild is Thief' do
        described_module.guild = 'Thief'
        expect(described_module.thief?).to be true
      end

      it 'returns false when guild is not Thief' do
        described_module.guild = 'Barbarian'
        expect(described_module.thief?).to be false
      end
    end

    describe '.trader?' do
      it 'returns true when guild is Trader' do
        described_module.guild = 'Trader'
        expect(described_module.trader?).to be true
      end

      it 'returns false when guild is not Trader' do
        described_module.guild = 'Moon Mage'
        expect(described_module.trader?).to be false
      end
    end

    describe '.warrior_mage?' do
      it 'returns true when guild is Warrior Mage' do
        described_module.guild = 'Warrior Mage'
        expect(described_module.warrior_mage?).to be true
      end

      it 'returns false when guild is not Warrior Mage' do
        described_module.guild = 'Necromancer'
        expect(described_module.warrior_mage?).to be false
      end
    end
  end
end
