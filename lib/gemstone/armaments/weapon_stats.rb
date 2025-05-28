require_relative "weapon_stats_brawling.rb"
require_relative "weapon_stats_hybrid.rb"
require_relative "weapon_stats_ranged.rb"
require_relative "weapon_stats_blunt.rb"
require_relative "weapon_stats_edged.rb"
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
        # damage types array:  Percent of damage that is of the type
        #  [0] = Slash    [1] = Crush    [2] = Puncture
        # damage factor array:
        #  [0] = nil (none)    [1] = Cloth    [2] = Leather    [3] = Scale    [4] = Chain    [5] = Plate
        # avd_by_asg array:
        #  Cloth:   [1] ASG 1    [2] nil      [3] nil      [4] nil
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
          polearm: @@weapon_stats_polearm,
          runestave: @@weapon_stats_runestave,
          thrown: @@weapon_stats_thrown,
          two_handed: @@weapon_stats_two_handed,
          unarmed: @@weapon_stats_unarmed,
        }

        # Finds the weapon's stats hash by one of its names.
        #
        # @param name [String] The name or alias of the weapon.
        # @return [Hash, nil] The stats hash of the matching weapon, or nil if not found.
        def self.find_weapon(name)
          _, weapon_info = @@weapon_stats.find { |_, stats| stats[:all_names].include?(name) }
          return weapon_info
        end

        # Finds the weapon's stats hash by one of its alternative names.
        #
        # @param name [String] The name or alias of the weapon.
        # @return [Symbol, nil] The weapon's category if found, otherwise nil.
        def self.find_category_by_name(name)
          _, weapon_info = @@weapon_stats.find { |_, stats| stats[:all_names].include?(name) }
          return weapon_info
        end

        def self.find_category_by_weapon_base(weapon_base)
          @@weapon_stats.each do |category, weapons|
            return category if weapons.key?(weapon_base)
          end
          nil
        end

        def self.find_df(weapon_base, asg) # i.e. find_damage_factor(:short_sword, 1) => 0.350
          category = find_category_by_weapon_base(weapon_base)
          @@weapon_stats[category][weapon_base][:damage_factor][asg] unless category.nil?
        end

        def self.find_avd(weapon_base, asg) # i.e. find_avd(:short_sword, 1) => 20
          category = find_category_by_weapon_base(weapon_base)
          @@weapon_stats[category][weapon_base][:avd_by_asg][asg] unless category.nil?
        end
      end
    end
  end
end
