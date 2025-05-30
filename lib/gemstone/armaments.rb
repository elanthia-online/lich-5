require_relative "armaments/armor_stats.rb"
require_relative "armaments/weapon_stats.rb"
require_relative "armaments/shield_stats.rb"

module Lich
  module Gemstone
    module Armaments
      ##
      # Finds matching equipment info by name.
      #
      # @param name [String] the equipment name or alias.
      # @return [Hash, nil] { type: :weapon|:armor|:shield, category: Symbol, data: Hash }
      def self.find(name)
        normalized = Lich::Util.normalize_name(name)

        if (data = WeaponStats.find_weapon(normalized))
          return { type: :weapon, category: WeaponStats.find_category(normalized), data: data }
        end

        if (data = ArmorStats.find_armor(normalized))
          return { type: :armor, category: ArmorStats.find_category(normalized), data: data }
        end

        if (data = ShieldStats.find_shield(normalized))
          return { type: :shield, category: ShieldStats.find_category(normalized), data: data }
        end

        nil
      end

      ##
      # Returns the top-level category type (:weapon, :armor, or :shield)
      #
      # @param name [String] the equipment name or alias.
      # @return [Symbol, nil] The category type or nil.
      def self.find_type(name)
        normalized = Lich::Util.normalize_name(name)

        return :weapon if WeaponStats.valid_weapon_name?(normalized)
        return :armor  if ArmorStats.valid_armor_name?(normalized)
        return :shield if ShieldStats.valid_shield_name?(normalized)
        nil
      end

      ##
      # Returns subcategory symbol (e.g., :edged, :plate, :tower_shield)
      #
      # @param name [String] the equipment name or alias.
      # @return [Symbol, nil] The specific category.
      def self.find_category(name)
        normalized = Lich::Util.normalize_name(name)

        WeaponStats.find_category(normalized) || ArmorStats.find_category(normalized) || ShieldStats.find_category(normalized)
      end

      ##
      # Determines if the name corresponds to any known item.
      #
      # @param name [String] The name to check.
      # @return [Boolean] True if valid, false otherwise.
      def self.valid_name?(name)
        normalized = Lich::Util.normalize_name(name)

        !find(normalized).nil?
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

      module Freezer
        ##
        # Recursively freezes a nested data structure in-place.
        #
        # This method ensures that all elements of deeply nested Arrays and Hashes are frozen,
        # including their keys and values. It helps prevent unintended mutations of static or
        # constant data, particularly useful for reference tables like weapon, armor, or shield stats.
        #
        # @param obj [Object] The object to be deeply frozen. Can be a Hash, Array, or any Ruby object.
        # @return [Object] The same object, after freezing all its elements recursively.
        #
        # @example Freezing a nested hash
        #   data = { stats: { damage: [1, 2, 3], type: "slash" } }
        #   Lich::Gemstone::Armaments::Freezer.deep_freeze(data)
        #   data.frozen?                   # => true
        #   data[:stats].frozen?           # => true
        #   data[:stats][:damage].frozen?  # => true
        def self.deep_freeze(obj)
          case obj
          when Hash
            obj.each do |k, v|
              deep_freeze(k)
              deep_freeze(v)
            end
          when Array
            obj.each { |el| deep_freeze(el) }
          end
          obj.freeze
        end
      end

      # Deep freeze all data structures in the Armaments module.
      Freezer.deep_freeze(@@weapon_stats)
      Freezer.deep_freeze(@@armor_stats)
      Freezer.deep_freeze(@@shield_stats)
    end
  end
end
