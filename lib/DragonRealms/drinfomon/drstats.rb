module Lich
  module DragonRealms
    module DRStats
      @@race = nil
      @@guild = nil
      @@gender = nil
      @@age ||= 0
      @@circle ||= 0
      @@strength ||= 0
      @@stamina ||= 0
      @@reflex ||= 0
      @@agility ||= 0
      @@intelligence ||= 0
      @@wisdom ||= 0
      @@discipline ||= 0
      @@charisma ||= 0
      @@favors ||= 0
      @@tdps ||= 0
      @@encumbrance = nil
      @@balance ||= 8
      @@luck ||= 0

      def self.race
        @@race
      end

      def self.race=(val)
        @@race = val
      end

      def self.guild
        @@guild
      end

      def self.guild=(val)
        @@guild = val
      end

      def self.gender
        @@gender
      end

      def self.gender=(val)
        @@gender = val
      end

      def self.age
        @@age
      end

      def self.age=(val)
        @@age = val
      end

      def self.circle
        @@circle
      end

      def self.circle=(val)
        @@circle = val
      end

      def self.strength
        @@strength
      end

      def self.strength=(val)
        @@strength = val
      end

      def self.stamina
        @@stamina
      end

      def self.stamina=(val)
        @@stamina = val
      end

      def self.reflex
        @@reflex
      end

      def self.reflex=(val)
        @@reflex = val
      end

      def self.agility
        @@agility
      end

      def self.agility=(val)
        @@agility = val
      end

      def self.intelligence
        @@intelligence
      end

      def self.intelligence=(val)
        @@intelligence = val
      end

      def self.wisdom
        @@wisdom
      end

      def self.wisdom=(val)
        @@wisdom = val
      end

      def self.discipline
        @@discipline
      end

      def self.discipline=(val)
        @@discipline = val
      end

      def self.charisma
        @@charisma
      end

      def self.charisma=(val)
        @@charisma = val
      end

      def self.favors
        @@favors
      end

      def self.favors=(val)
        @@favors = val
      end

      def self.tdps
        @@tdps
      end

      def self.tdps=(val)
        @@tdps = val
      end

      def self.luck
        @@luck
      end

      def self.luck=(val)
        @@luck = val
      end

      def self.balance
        @@balance
      end

      def self.balance=(val)
        @@balance = val
      end

      def self.encumbrance
        @@encumbrance
      end

      def self.encumbrance=(val)
        @@encumbrance = val
      end

      def self.name
        XMLData.name
      end

      def self.health
        XMLData.health
      end

      def self.mana
        XMLData.mana
      end

      def self.fatigue
        XMLData.stamina
      end

      def self.spirit
        XMLData.spirit
      end

      def self.concentration
        XMLData.concentration
      end

      def self.native_mana
        case DRStats.guild
        when 'Necromancer'
          'arcane'
        when 'Barbarian', 'Thief'
          nil
        when 'Moon Mage', 'Trader'
          'lunar'
        when 'Warrior Mage', 'Bard'
          'elemental'
        when 'Cleric', 'Paladin'
          'holy'
        when 'Empath', 'Ranger'
          'life'
        end
      end

      def self.serialize
        [@@race, @@guild, @@gender, @@age, @@circle, @@strength, @@stamina, @@reflex, @@agility, @@intelligence, @@wisdom, @@discipline, @@charisma, @@favors, @@tdps, @@luck, @@encumbrance]
      end

      def self.load_serialized=(array)
        @@race, @@guild, @@gender, @@age = array[0..3]
        @@circle, @@strength, @@stamina, @@reflex, @@agility, @@intelligence, @@wisdom, @@discipline, @@charisma, @@favors, @@tdps, @@luck, @@encumbrance = array[5..12]
      end

      def self.barbarian?
        @@guild == 'Barbarian'
      end

      def self.bard?
        @@guild == 'Bard'
      end

      def self.cleric?
        @@guild == 'Cleric'
      end

      def self.commoner?
        @@guild == 'Commoner'
      end

      def self.empath?
        @@guild == 'Empath'
      end

      def self.moon_mage?
        @@guild == 'Moon Mage'
      end

      def self.necromancer?
        @@guild == 'Necromancer'
      end

      def self.paladin?
        @@guild == 'Paladin'
      end

      def self.ranger?
        @@guild == 'Ranger'
      end

      def self.thief?
        @@guild == 'Thief'
      end

      def self.trader?
        @@guild == 'Trader'
      end

      def self.warrior_mage?
        @@guild == 'Warrior Mage'
      end
    end
  end
end
