# The root module for all Lich-related functionality.
module Lich
  # Submodule for GemStone IV-specific logic.
  module Gemstone
    # The Ascension module manages character ascension skills.
    #
    # It provides lookup tables for ascension skill names, methods to query skill availability,
    # affordability, and knowledge, and dynamically defines shortcut methods for all ascension skills.
    #
    # Each skill includes:
    # - a long name (as used in internal references)
    # - a short name (used as a shortcut method)
    # - a cost (currently hardcoded to 0)
    #
    # Example:
    #   if Ascension.available?("discipline")
    #     Ascension.use("discipline")
    #   end
    module Ascension
      # Returns an array of all defined Ascension skill mappings.
      #
      # @return [Array<Hash>] Array of hashes, each containing :long_name, :short_name, and :cost
      def self.ascension_lookups
        [{ long_name: 'acid_resistance',           short_name: 'resistacid',      cost: { stamina: 0 } },
         { long_name: 'agility',                   short_name: 'agility',         cost: { stamina: 0 } },
         { long_name: 'ambush',                    short_name: 'ambush',          cost: { stamina: 0 } },
         { long_name: 'arcane_symbols',            short_name: 'arcanesymbols',   cost: { stamina: 0 } },
         { long_name: 'armor_use',                 short_name: 'armoruse',        cost: { stamina: 0 } },
         { long_name: 'aura',                      short_name: 'aura',            cost: { stamina: 0 } },
         { long_name: 'blunt_weapons',             short_name: 'bluntweapons',    cost: { stamina: 0 } },
         { long_name: 'brawling',                  short_name: 'brawling',        cost: { stamina: 0 } },
         { long_name: 'climbing',                  short_name: 'climbing',        cost: { stamina: 0 } },
         { long_name: 'cold_resistance',           short_name: 'resistcold',      cost: { stamina: 0 } },
         { long_name: 'combat_maneuvers',          short_name: 'combatmaneuvers', cost: { stamina: 0 } },
         { long_name: 'constitution',              short_name: 'constitution',    cost: { stamina: 0 } },
         { long_name: 'crush_resistance',          short_name: 'resistcrush',     cost: { stamina: 0 } },
         { long_name: 'dexterity',                 short_name: 'dexterity',       cost: { stamina: 0 } },
         { long_name: 'disarming_traps',           short_name: 'disarmingtraps',  cost: { stamina: 0 } },
         { long_name: 'discipline',                short_name: 'discipline',      cost: { stamina: 0 } },
         { long_name: 'disintegration_resistance', short_name: 'resistdisintegr', cost: { stamina: 0 } },
         { long_name: 'disruption_resistance',     short_name: 'resistdisruptio', cost: { stamina: 0 } },
         { long_name: 'dodging',                   short_name: 'dodging',         cost: { stamina: 0 } },
         { long_name: 'edged_weapons',             short_name: 'edgedweapons',    cost: { stamina: 0 } },
         { long_name: 'electric_resistance',       short_name: 'resistelectric',  cost: { stamina: 0 } },
         { long_name: 'elemental_lore_air',        short_name: 'elair',           cost: { stamina: 0 } },
         { long_name: 'elemental_lore_earth',      short_name: 'elearth',         cost: { stamina: 0 } },
         { long_name: 'elemental_lore_fire',       short_name: 'elfire',          cost: { stamina: 0 } },
         { long_name: 'elemental_lore_water',      short_name: 'elwater',         cost: { stamina: 0 } },
         { long_name: 'elemental_mana_control',    short_name: 'elementalmc',     cost: { stamina: 0 } },
         { long_name: 'first_aid',                 short_name: 'firstaid',        cost: { stamina: 0 } },
         { long_name: 'grapple_resistance',        short_name: 'resistgrapple',   cost: { stamina: 0 } },
         { long_name: 'harness_power',             short_name: 'harnesspower',    cost: { stamina: 0 } },
         { long_name: 'health_regeneration',       short_name: 'regenhealth',     cost: { stamina: 0 } },
         { long_name: 'heat_resistance',           short_name: 'resistheat',      cost: { stamina: 0 } },
         { long_name: 'impact_resistance',         short_name: 'resistimpact',    cost: { stamina: 0 } },
         { long_name: 'influence',                 short_name: 'influence',       cost: { stamina: 0 } },
         { long_name: 'intuition',                 short_name: 'intuition',       cost: { stamina: 0 } },
         { long_name: 'logic',                     short_name: 'logic',           cost: { stamina: 0 } },
         { long_name: 'magic_item_use',            short_name: 'magicitemuse',    cost: { stamina: 0 } },
         { long_name: 'mana_regeneration',         short_name: 'regenmana',       cost: { stamina: 0 } },
         { long_name: 'mental_lore_divination',    short_name: 'mldivination',    cost: { stamina: 0 } },
         { long_name: 'mental_lore_manipulation',  short_name: 'mlmanipulation',  cost: { stamina: 0 } },
         { long_name: 'mental_lore_telepathy',     short_name: 'mltelepathy',     cost: { stamina: 0 } },
         { long_name: 'mental_lore_transference',  short_name: 'mltransference',  cost: { stamina: 0 } },
         { long_name: 'mental_lore_transform',     short_name: 'mltransform',     cost: { stamina: 0 } },
         { long_name: 'mental_mana_control',       short_name: 'mentalmc',        cost: { stamina: 0 } },
         { long_name: 'multi_opponent_combat',     short_name: 'multiopponent',   cost: { stamina: 0 } },
         { long_name: 'perception',                short_name: 'perception',      cost: { stamina: 0 } },
         { long_name: 'physical_fitness',          short_name: 'physicalfitness', cost: { stamina: 0 } },
         { long_name: 'picking_locks',             short_name: 'pickinglocks',    cost: { stamina: 0 } },
         { long_name: 'picking_pockets',           short_name: 'pickingpockets',  cost: { stamina: 0 } },
         { long_name: 'plasma_resistance',         short_name: 'resistplasma',    cost: { stamina: 0 } },
         { long_name: 'polearm_weapons',           short_name: 'polearmsweapons', cost: { stamina: 0 } },
         { long_name: 'porter',                    short_name: 'porter',          cost: { stamina: 0 } },
         { long_name: 'puncture_resistance',       short_name: 'resistpuncture',  cost: { stamina: 0 } },
         { long_name: 'ranged_weapons',            short_name: 'rangedweapons',   cost: { stamina: 0 } },
         { long_name: 'shield_use',                short_name: 'shielduse',       cost: { stamina: 0 } },
         { long_name: 'slash_resistance',          short_name: 'resistslash',     cost: { stamina: 0 } },
         { long_name: 'sorcerous_lore_demonology', short_name: 'soldemonology',   cost: { stamina: 0 } },
         { long_name: 'sorcerous_lore_necromancy', short_name: 'solnecromancy',   cost: { stamina: 0 } },
         { long_name: 'spell_aiming',              short_name: 'spellaiming',     cost: { stamina: 0 } },
         { long_name: 'spirit_mana_control',       short_name: 'spiritmc',        cost: { stamina: 0 } },
         { long_name: 'spiritual_lore_blessings',  short_name: 'slblessings',     cost: { stamina: 0 } },
         { long_name: 'spiritual_lore_religion',   short_name: 'slreligion',      cost: { stamina: 0 } },
         { long_name: 'spiritual_lore_summoning',  short_name: 'slsummoning',     cost: { stamina: 0 } },
         { long_name: 'stalking_and_hiding',       short_name: 'stalking',        cost: { stamina: 0 } },
         { long_name: 'stamina_regeneration',      short_name: 'regenstamina',    cost: { stamina: 0 } },
         { long_name: 'steam_resistance',          short_name: 'resiststeam',     cost: { stamina: 0 } },
         { long_name: 'strength',                  short_name: 'strength',        cost: { stamina: 0 } },
         { long_name: 'survival',                  short_name: 'survival',        cost: { stamina: 0 } },
         { long_name: 'swimming',                  short_name: 'swimming',        cost: { stamina: 0 } },
         { long_name: 'thrown_weapons',            short_name: 'thrownweapons',   cost: { stamina: 0 } },
         { long_name: 'trading',                   short_name: 'trading',         cost: { stamina: 0 } },
         { long_name: 'two_weapon_combat',         short_name: 'twoweaponcombat', cost: { stamina: 0 } },
         { long_name: 'two_handed_weapons',        short_name: 'twohandedweapon', cost: { stamina: 0 } },
         { long_name: 'unbalance_resistance',      short_name: 'resistunbalance', cost: { stamina: 0 } },
         { long_name: 'vacuum_resistance',         short_name: 'resistvacuum',    cost: { stamina: 0 } },
         { long_name: 'wisdom',                    short_name: 'wisdom',          cost: { stamina: 0 } },
         { long_name: 'transcend_destiny',         short_name: 'trandest',        cost: { stamina: 0 } }]
      end

      # Retrieves the character's rank in the specified ascension skill.
      #
      # @param name [String] The name of the ascension skill
      # @return [Integer] The current rank (or 0 if unknown)
      # @example
      #   Ascension['discipline'] # => 3  # knows 3 ranks of discipline
      #   Ascension['influence'] # => 0  # does not have any ranks in influence
      def Ascension.[](name)
        return PSMS.assess(name, 'Ascension')
      end

      # Checks if the character has at least one rank in the specified ascension skill.
      #
      # @param name [String] The ascension skill name
      # @return [Boolean] True if known
      # @example
      #   Ascension.known?('discipline') # => true  # has at least one rank in discipline
      #   Ascension.known?('influence') # => false  # does not have any ranks in influence
      def Ascension.known?(name)
        Ascension[name] > 0
      end

      # Checks if the ascension skill can be afforded (based on FORCERT or other gating logic).
      #
      # @param name [String] The ascension skill name
      # @return [Boolean] True if affordable
      # @example
      #   Ascension.affordable?('discipline') # => true  # no cost, so always affordable
      def Ascension.affordable?(name)
        return PSMS.assess(name, 'Ascension', true)
      end

      # Determines if the ascension skill is available for use.
      #
      # @param name [String] The ascension skill name
      # @return [Boolean] True if known, affordable, and not blocked by cooldowns or debuffs
      # @example
      #   Ascension.available?('discipline') # => true  # known, affordable, not on cooldown, and not overexerted
      #   Ascension.available?('influence') # => false  # not known
      def Ascension.available?(name)
        Ascension.known?(name) &&
          Ascension.affordable?(name) &&
          PSMS.available?(name)
      end

      # Dynamically defines shortcut methods for each ascension skill using both short and long names.
      Ascension.ascension_lookups.each { |ascension|
        self.define_singleton_method(ascension[:short_name]) do
          Ascension[ascension[:short_name]]
        end

        self.define_singleton_method(ascension[:long_name]) do
          Ascension[ascension[:short_name]]
        end
      }
    end
  end
end
