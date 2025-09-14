require_relative "armaments/armor_stats.rb"
require_relative "armaments/weapon_stats.rb"
require_relative "armaments/shield_stats.rb"

module Lich
  module Gemstone
    module Armaments
      ##
      # Maps armor group (AG) index to human-readable armor group names.
      #
      # @type [Hash{Integer => String}]
      # @example AG_INDEX_TO_NAME[1] #=> "Cloth"
      AG_INDEX_TO_NAME = {
        1 => "Cloth",
        2 => "Soft Leather",
        3 => "Rigid Leather",
        4 => "Chain",
        5 => "Plate"
      }.freeze

      ##
      # Maps armor subgroup (ASG) index to human-readable armor subgroup names.
      #
      # @type [Hash{Integer => String}]
      # @example ASG_INDEX_TO_NAME[10] #=> "Brigandine"
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

      ##
      # Maps spell circle index to a hash with full name and abbreviation.
      #
      # @type [Hash{Integer => Hash}]
      # @example SPELL_CIRCLE_INDEX_TO_NAME[1] #=> { name: "Minor Spiritual", abbr: "MinSp" }
      SPELL_CIRCLE_INDEX_TO_NAME = {
        0  => { name: "Action",                  abbr: "Act"    },
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

        if (data = WeaponStats.find(name))
          return { type: :weapon, data: data }
        end

        if (data = ArmorStats.find(name))
          return { type: :armor, data: data }
        end

        if (data = ShieldStats.find(name))
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

        return true unless Armaments.find(name).nil? # if we found it, then it's valid
        return false # if nil, then the name was not found and it's not a valid name
      end

      ##
      # Lists all known names across all equipment types.
      #
      # @param type [Symbol, nil] :weapon, :armor, or :shield. If nil, includes all.
      # @return [Array<String>] List of names.
      def self.names(type = nil)
        case type
        when :weapon then WeaponStats.names
        when :armor  then ArmorStats.names
        when :shield then ShieldStats.names
        else
          WeaponStats.names + ArmorStats.names + ShieldStats.names
        end.uniq
      end

      ##
      # Lists all subcategories for a given type.
      #
      # @param type [Symbol, nil] :weapon, :armor, or :shield. If nil, includes all.
      # @return [Array<Symbol>] List of category keys.
      def self.categories(type = nil)
        case type
        when :weapon then WeaponStats.categories
        when :armor  then ArmorStats.categories
        when :shield then ShieldStats.categories
        else
          WeaponStats.categories + ArmorStats.categories + ShieldStats.categories
        end.uniq
      end

      ##
      # Determines the type of item for a given name.
      #
      # @param name [String] the item name or alias
      # @return [Symbol, nil] the type of the item: :weapon, :armor, :shield, or nil if not found
      def self.type_for(name)
        name = name.downcase.strip

        return :weapon if WeaponStats.find(name)
        return :armor if ArmorStats.find(name)
        return :shield if ShieldStats.find(name)

        nil
      end

      ##
      # Returns the category of the item with the given name by delegating to the appropriate stats module.
      #
      # This avoids redundant lookups by letting each submodule handle the logic internally.
      #
      # @param name [String] the item name or alias
      # @return [Symbol, nil] the category (e.g., :OHE, :full_plate, :tower) or nil if not found
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
