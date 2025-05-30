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

        # Finds the weapon's stats hash by one of its names.
        #
        # @param name [String] The name or alias of the weapon.
        # @param category [Symbol, nil] (optional) The weapon category to narrow the search.
        # @return [Hash, nil] The stats hash of the matching weapon, or nil if not found.
        def self.find_weapon(name, category = nil)
          unless category.nil?
            weapons = @@weapon_stats[category]
            return nil unless weapons

            weapons.each_value do |weapon_info|
              return weapon_info if weapon_info[:all_names]&.include?(name)
            end
          else
            @@weapon_stats.each_value do |weapons|
              weapons.each_value do |weapon_info|
                return weapon_info if weapon_info[:all_names]&.include?(name)
              end
            end
          end
          nil
        end
      end
    end
  end
end
