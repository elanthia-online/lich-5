require_relative "armaments/armor_stats.rb"
require_relative "armaments/weapon_stats.rb"
require_relative "armaments/shield_stats.rb"

module Lich
  module Gemstone
    module Armaments
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
      # Returns the top-level category type (:weapon, :armor, or :shield)
      #
      # @param name [String] the equipment name or alias.
      # @return [Symbol, nil] The category type or nil.
      def self.find_type(name)
        name = name.downcase.strip

        return :weapon if WeaponStats.valid_weapon_name?(name)
        return :armor  if ArmorStats.valid_armor_name?(name)
        return :shield if ShieldStats.valid_shield_name?(name)
        nil
      end

      ##
      # Returns subcategory symbol (e.g., :edged, :plate, :tower_shield)
      #
      # @param name [String] the equipment name or alias.
      # @return [Symbol, nil] The specific category.
      def self.find_category(name)
        name = name.downcase.strip

        WeaponStats.find_category(name) || ArmorStats.find_category(name) || ShieldStats.find_category(name)
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
      # Returns the category of the item with the given name.
      #
      # For weapons, this is the weapon category (e.g., :OHE).
      # For shields, this is the shield size category (e.g., :medium).
      # For armor, this is the ASG symbol (e.g., :asg_18).
      #
      # @param name [String] the item name or alias
      # @return [Symbol, nil] the category symbol or nil if not found
      def self.category_for(name)
        name = name.downcase.strip

        WeaponStats.all_categories.each do |cat|
          weapon = WeaponStats.all_weapons_in_category(cat).find do |entry|
            entry[:all_names]&.map(&:downcase)&.include?(name)
          end
          return cat if weapon
        end

        ArmorStats.send(:@@armor_stats).each_value do |subgroup|
          subgroup.each do |asg_sym, entry|
            return asg_sym if entry[:all_names]&.map(&:downcase)&.include?(name)
          end
        end

        ShieldStats.all_shield_categories.each do |cat|
          shield = ShieldStats.find_shield(name)
          return shield[:category] if shield
        end

        nil
      end
    end
  end
end
