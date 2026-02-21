# frozen_string_literal: true

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

      # Guilds and their native mana types, frozen for immutability.
      GUILD_MANA_TYPES = {
        'Necromancer'  => 'arcane',
        'Barbarian'    => nil,
        'Thief'        => nil,
        'Moon Mage'    => 'lunar',
        'Trader'       => 'lunar',
        'Warrior Mage' => 'elemental',
        'Bard'         => 'elemental',
        'Cleric'       => 'holy',
        'Paladin'      => 'holy',
        'Empath'       => 'life',
        'Ranger'       => 'life'
      }.freeze

      def self.native_mana
        GUILD_MANA_TYPES[@@guild]
      end

      # Serialization order (17 elements, indices 0-16):
      # 0: race, 1: guild, 2: gender, 3: age, 4: circle,
      # 5: strength, 6: stamina, 7: reflex, 8: agility,
      # 9: intelligence, 10: wisdom, 11: discipline, 12: charisma,
      # 13: favors, 14: tdps, 15: luck, 16: encumbrance
      def self.serialize
        [@@race, @@guild, @@gender, @@age, @@circle, @@strength, @@stamina, @@reflex, @@agility, @@intelligence, @@wisdom, @@discipline, @@charisma, @@favors, @@tdps, @@luck, @@encumbrance]
      end

      # BUG FIX: Original code used array[5..12] which only provides 8 elements
      # but tried to assign to 13 variables (circle + 12 stats), causing data loss.
      # The correct slice is array[4..16] for the remaining 13 variables.
      def self.load_serialized=(array)
        return if array.nil? || array.empty?

        @@race, @@guild, @@gender, @@age = array[0..3]
        @@circle, @@strength, @@stamina, @@reflex, @@agility, @@intelligence, @@wisdom, @@discipline, @@charisma, @@favors, @@tdps, @@luck, @@encumbrance = array[4..16]
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
