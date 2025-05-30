require_relative "weapon_stats_brawling.rb"
require_relative "weapon_stats_hybrid.rb"
require_relative "weapon_stats_ranged.rb"
require_relative "weapon_stats_blunt.rb"
require_relative "weapon_stats_edged.rb"
require_relative "weapon_stats_natural.rb"
require_relative "weapon_stats_polearm.rb"
require_relative "weapon_stats_runestave.rb"
require_relative "weapon_stats_thrown.rb"
require_relative "weapon_stats_two_handed.rb"
require_relative "weapon_stats_unarmed.rb"

module Lich
  module Gemstone
    module Armaments
      # WeaponStats module contains metadata definitions for individual weapons,
      # including their category, base and alternate names, damage profiles,
      # effectiveness against armor, and attack speeds.
      module WeaponStats
        # Static array of weapon stats indexed by weapon identifiers. Each weapon
        # entry contains metadata such as category, base name, alternative names,
        # damage types, damage factors, armor avoidance by armor size group (ASG),
        # base roundtime (RT), and minimum RT.
        #
        # damage_types: Hash of damage type percentages or values.
        #   :slash    => % of slash damage (Float or nil)
        #   :crush    => % of crush damage (Float or nil)
        #   :puncture => % of puncture damage (Float or nil)
        #   :special  => Array of special damage types (or nil)
        #
        # damage factor array:
        #  [0] = nil (none)    [1] = Cloth    [2] = Leather    [3] = Scale    [4] = Chain    [5] = Plate
        #
        # avd_by_asg array:
        #  Cloth:   [1] ASG 1    [2] ASG 2      [3] nil      [4] nil
        #  Leather: [5] ASG 5    [6] ASG 6    [7] ASG 7    [8] ASG 8
        #  Scale:   [9] ASG 9    [10] ASG 10  [11] ASG 11  [12] ASG 12
        #  Chain:   [13] ASG 13  [14] ASG 14  [15] ASG 15  [16] ASG 16
        #  Plate:   [17] ASG 17  [18] ASG 18  [19] ASG 19  [20] ASG 20

        @@weapon_stats = {
          brawling: @@weapon_stats_brawling,
          hybrid: @@weapon_stats_hybrid,
          missile: @@weapon_stats_ranged,
          blunt: @@weapon_stats_blunt,
          edged: @@weapon_stats_edged,
          natural: @@weapon_stats_natural,
          polearm: @@weapon_stats_polearm,
          runestave: @@weapon_stats_runestave,
          thrown: @@weapon_stats_thrown,
          two_handed: @@weapon_stats_two_handed,
          unarmed: @@weapon_stats_unarmed,
        }

        ##
        # Finds the weapon's stats hash by one of its names.
        #
        # @param name [String] The name or alias of the weapon.
        # @param category [Symbol, nil] (optional) The weapon category to narrow the search.
        # @return [Hash, nil] The stats hash of the matching weapon, or nil if not found.
        def self.find_weapon(name, category = nil)
          normalized = Lich::Util.normalize_name(name)

          unless category.nil?
            weapons = @@weapon_stats[category]
            return nil unless weapons

            weapons.each_value do |weapon_info|
              return weapon_info if weapon_info[:all_names]&.include?(normalized)
            end
          else
            @@weapon_stats.each_value do |weapons|
              weapons.each_value do |weapon_info|
                return weapon_info if weapon_info[:all_names]&.include?(normalized)
              end
            end
          end
          nil
        end

        ##
        # Lists all weapon base names, optionally filtered by weapon category.
        #
        # @param category [Symbol, nil] the weapon category to limit the results (e.g., :edged, :polearm)
        # @return [Array<String>] an array of base weapon names
        def self.list_weapons(category = nil)
          result = []
          if category
            @@weapon_stats[category]&.each_value do |weapon_info|
              result << weapon_info[:base_name]
            end
          else
            @@weapon_stats.each_value do |weapons|
              weapons.each_value { |weapon_info| result << weapon_info[:base_name] }
            end
          end
          result.uniq
        end

        ##
        # Returns a list of all defined weapon categories.
        #
        # @return [Array<Symbol>] an array of weapon category symbols
        def self.categories
          @@weapon_stats.keys
        end

        ##
        # Returns a simplified hash of a weapon’s damage type breakdown.
        #
        # @param name [String] a weapon name or alias
        # @param category [Symbol, nil] optional category to narrow the search
        # @return [Hash, nil] damage type summary or nil if not found
        def self.damage_summary(name, category = nil)
          normalized = Lich::Util.normalize_name(name)

          weapon = find_weapon(normalized, category)
          return nil unless weapon

          {
            base_name: weapon[:base_name],
            slash: weapon[:damage_types][:slash],
            crush: weapon[:damage_types][:crush],
            puncture: weapon[:damage_types][:puncture],
            special: weapon[:damage_types][:special]
          }
        end

        ##
        # Returns all recognized names for a given weapon.
        #
        # @param name [String] the base name or any alias of the weapon
        # @param category [Symbol, nil] optional category to limit the search
        # @return [Array<String>] an array of all recognized names for the weapon
        def self.aliases_for(name, category = nil)
          normalized = Lich::Util.normalize_name(name)

          weapon = find_weapon(normalized, category)
          weapon ? weapon[:all_names] : []
        end

        ##
        # Compares two weapons and returns key stat differences.
        #
        # @param name1 [String] first weapon name or alias
        # @param name2 [String] second weapon name or alias
        # @param category1 [Symbol, nil] optional category for first weapon
        # @param category2 [Symbol, nil] optional category for second weapon
        # @return [Hash, nil] comparison data or nil if either weapon not found
        def self.compare_weapons(name1, name2, category1 = nil, category2 = nil)
          normalized1 = Lich::Util.normalize_name(name1)
          normalized2 = Lich::Util.normalize_name(name2)

          w1 = find_weapon(normalized1, category1)
          w2 = find_weapon(normalized2, category2)
          return nil unless w1 && w2

          {
            name1: w1[:base_name],
            name2: w2[:base_name],
            damage_types: [w1[:damage_types], w2[:damage_types]],
            damage_factors: [w1[:damage_factor], w2[:damage_factor]],
            avd_by_asg: [w1[:avd_by_asg], w2[:avd_by_asg]],
            base_rt: [w1[:base_rt], w2[:base_rt]],
            min_rt: [w1[:min_rt], w2[:min_rt]]
          }
        end
      end
    end
  end
end
