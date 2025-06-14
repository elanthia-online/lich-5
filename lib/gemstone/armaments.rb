require_relative "armaments/armor_stats.rb"
require_relative "armaments/weapon_stats.rb"
require_relative "armaments/shield_stats.rb"

module Lich
  module Gemstone
    module Armaments
      AG_INDEX_TO_NAME = {
        1 => "Cloth",
        2 => "Soft Leather",
        3 => "Rigid Leather",
        4 => "Chain",
        5 => "Plate"
      }.freeze

      ASG_INDEX_TO_NAME = {
        1  => "Robes",
        2  => "Light Leather",
        3  => "Full Leather",
        4  => "Double Leather",
        5  => "Leather Breastplate",
        6  => "Cuirbouilli",
        7  => "Studded Leather",
        8  => "Reinforced Leather",
        9  => "Hardened Leather",
        10 => "Brigandine",
        11 => "Chain Mail",
        12 => "Double Chain",
        13 => "Augmented Chain",
        14 => "Chain Hauberk",
        15 => "Metal Breastplate",
        16 => "Augmented Breastplate",
        17 => "Half Plate",
        18 => "Full Plate",
        19 => "Field Plate",
        20 => "Augmented Plate"
      }.freeze

      SPELL_CIRCLE_INDEX_TO_NAME = {
        0  => { name: "Action Penalty",          abbr: "ActPn"  },
        1  => { name: "Minor Spiritual",         abbr: "MinSp"  },
        2  => { name: "Major Spiritual",         abbr: "MajSp"  },
        3  => { name: "Cleric",                  abbr: "Clerc"  },
        4  => { name: "Minor Elemental",         abbr: "MinEl"  },
        5  => { name: "Major Elemental",         abbr: "MajEl"  },
        6  => { name: "Ranger",                  abbr: "Rngr"   },
        7  => { name: "Sorcerer",                abbr: "Sorc"   },
        8  => { name: "Old Empath (Deprecated)", abbr: "OldEm"  },
        9  => { name: "Wizard",                  abbr: "Wiz"    },
        10 => { name: "Bard",                    abbr: "Bard"   },
        11 => { name: "Empath",                  abbr: "Emp"    },
        12 => { name: "Minor Mental",            abbr: "MinMn"  },
        13 => { name: "Major Mental",            abbr: "MajMn"  },
        14 => { name: "Savant",                  abbr: "Sav"    },
        15 => { name: "Unused",                  abbr: " - "    },
        16 => { name: "Paladin",                 abbr: "Pal"    },
        17 => { name: "Arcane Spells",           abbr: "Arcne"  },
        18 => { name: "Unused",                  abbr: " - "    },
        19 => { name: "Lost Arts",               abbr: "Lost"   },
      }.freeze

      ##
      # Finds matching armament info by name.
      #
      # @param name [String] the equipment name or alias.
      # @return [Hash, nil] { type: :weapon|:armor|:shield, data: Hash }
      def self.find(name)
        name = name.downcase.strip

        if (data = WeaponStats.find_weapon(name))
          return { type: :weapon, data: data }
        end

        if (data = ArmorStats.find_armor(name))
          return { type: :armor, data: data }
        end

        if (data = ShieldStats.find_shield(name))
          return { type: :shield, data: data }
        end

        nil
      end

      ##
      # Determines if the name corresponds to any known item.
      #
      # @param name [String] The name to check.
      # @return [Boolean] True if valid, false otherwise.
      def self.valid_name?(name)
        name = name.downcase.strip

        !find(name).nil?
      end

      ##
      # Lists all known names across all equipment types.
      #
      # @param type [Symbol, nil] :weapon, :armor, or :shield. If nil, includes all.
      # @return [Array<String>] List of names.
      def self.all_names(type = nil)
        case type
        when :weapon then WeaponStats.all_names
        when :armor  then ArmorStats.all_names
        when :shield then ShieldStats.all_names
        else
          WeaponStats.all_names + ArmorStats.all_names + ShieldStats.all_names
        end.uniq
      end

      ##
      # Lists all subcategories for a given type.
      #
      # @param type [Symbol, nil] :weapon, :armor, or :shield. If nil, includes all.
      # @return [Array<Symbol>] List of category keys.
      def self.all_categories(type = nil)
        case type
        when :weapon then WeaponStats.all_categories
        when :armor  then ArmorStats.all_categories
        when :shield then ShieldStats.all_categories
        else
          WeaponStats.all_categories + ArmorStats.all_categories + ShieldStats.all_categories
        end.uniq
      end

      ##
      # Determines the type of item for a given name.
      #
      # @param name [String] the item name or alias
      # @return [Symbol, nil] the type of the item: :weapon, :armor, :shield, or nil if not found
      def self.type_for(name)
        name = name.downcase.strip

        return :weapon if WeaponStats.find_weapon(name)
        return :armor if ArmorStats.find_armor(name)
        return :shield if ShieldStats.find_shield(name)

        nil
      end

      ##
      # Returns the category of the item with the given name by delegating to the appropriate stats module.
      #
      # This avoids redundant lookups by letting each submodule handle the logic internally.
      #
      # @param name [String] the item name or alias
      # @return [Symbol, String, nil] the category (e.g., :OHE, "full plate", :tower) or nil if not found
      def self.category_for(name)
        name = name.downcase.strip

        category = WeaponStats.category_for(name)
        return category unless category.nil?

        category = ArmorStats.category_for(name)
        return category unless category.nil?

        category = ShieldStats.category_for(name)
        return category unless category.nil?

        nil
      end
    end
  end
end
