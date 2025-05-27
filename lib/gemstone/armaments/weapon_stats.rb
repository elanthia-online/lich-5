require_relative "armaments/weapon_stats_ohe.rb"

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
        #  [0] = Cloth    [1] = Leather    [2] = Scale    [3] = Chain    [4] = Plate
        # avd_by_asg array:
        #  Cloth:   [0] ASG 1
        #  Leather: [1] ASG 5    [2] ASG 6    [3] ASG 7    [4] ASG 8
        #  Scale:   [5] ASG 9    [6] ASG 10   [7] ASG 11   [8] ASG 12
        #  Chain:   [9] ASG 13   [10] ASG 14  [11] ASG 15  [12] ASG 16
        #  Plate:   [13] ASG 17  [14] ASG 18  [15] ASG 19  [16] ASG 20
        @@weapon_stats = [
          # OHE Weapons
          "arrow"       => { # when swung, not when fired
            :category      => :OHE,
            :base_name     => "arrow",
            :all_names     => ["sitka", "arrow"],
            :damage_types  => [33.3, 0.0, 66.7],
            :damage_factor => [0.200, 0.100, 0.080, 0.100, 0.040],
            #               Cloth  / Leather       / Scale      / Chain       / Plate
            :avd_by_asg    => [20, 18, 17, 16, 15, 10, 8, 6, 4, 5, 1, -3, -7, -5, -11, -17, -23],
            :base_rt       => 5,
            :min_rt        => 4,
          },
          "dagger"      => {
            :category      => :OHE,
            :base_name     => "dagger",
            :all_names     => ["alfange", "basilard", "bodice dagger", "bodkin", "boot dagger", "bracelet dagger", "butcher knife", "cinquedea", "crescent dagger", "dagger", "dirk", "fantail dagger", "forked dagger", "gimlet knife", "kaiken", "kidney dagger", "knife", "kozuka", "krizta", "kubikiri", "misericord", "parazonium", "pavade", "poignard", "pugio", "push dagger", "scramasax", "sgian achlais", "sgian dubh", "sidearm-of-Onar", "spike", "stiletto", "tanto", "trail knife", "trailknife", "zirah bouk"],
            :damage_types  => [33.3, 0.0, 66.7],
            :damage_factor => [0.250, 0.200, 0.100, 0.125, 0.075],
            #               Cloth  / Leather       / Scale        / Chain       / Plate
            :avd_by_asg    => [25, 23, 22, 21, 20, 15, 13, 11, 9, 10, 6, 2, -2, 0, -6, -12, -18],
            :base_rt       => 1,
            :min_rt        => 2,
          },
          "main_gauche" => {
            :category      => :OHE,
            :base_name     => "main gauche",
            :all_names     => ["parrying dagger", "main gauche", "shield-sword", "sword-breaker"],
            :damage_types  => [33.3, 0.0, 66.7],
            :damage_factor => [0.275, 0.210, 0.110, 0.125, 0.075],
            #               Cloth  / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [27, 25, 24, 23, 22, 20, 18, 16, 14, 20, 16, 12, 8, 20, 14, 8, 2],
            :base_rt       => 2,
            :min_rt        => 3,
          },
          "rapier"      => {
            :category      => :OHE,
            :base_name     => "rapier",
            :all_names     => ["bilbo", "colichemarde", "epee", "fleuret", "foil", "rapier", "schlager", "tizona", "tock", "tocke", "tuck", "verdun"],
            :damage_types  => [33.3, 0.0, 66.7],
            :damage_factor => [0.325, 0.225, 0.125, 0.125, 0.075],
            #               Cloth  / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [45, 40, 39, 38, 37, 30, 28, 26, 24, 35, 31, 27, 23, 15, 9, 3, -3],
            :base_rt       => 2,
            :min_rt        => 3,
          },
          "whip-blade"  => {
            :category      => :OHE,
            :base_name     => "whip-blade",
            :all_names     => ["whip-blade", "whipblade"],
            :damage_types  => [100.0, 0.0, 0.0],
            :damage_factor => [0.333, 0.225, 0.125, 0.115, 0.065],
            #               Cloth  / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [45, 40, 39, 38, 37, 30, 28, 26, 24, 35, 31, 27, 23, 15, 9, 3, -3],
            :base_rt       => 2,
            :min_rt        => 3,
          },
          "katar"       => {
            :category      => :HYBRID,
            :hybrid_skills => [:OHE, :BRAWL],
            :base_name     => "katar",
            :all_names     => ["gauntlet-sword", "kunai", "manople", "paiscush", "pata", "slasher", "tvekre"],
            :damage_types  => [33.3, 0.0, 66.7],
            :damage_factor => [0.325, 0.250, 0.225, 0.200, 0.175],
            #               Cloth  / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [30, 32, 31, 30, 29, 40, 38, 36, 34, 45, 41, 37, 33, 40, 34, 28, 22],
            :base_rt       => 3,
            :min_rt        => 3,
          },
          "short_sword" => {
            :category      => :OHE,
            :base_name     => "short sword",
            :all_names     => ["acinaces", "antler sword", "backslasher", "braquemar", "baselard", "chereb", "coustille", "gladius", "gladius graecus", "kris", "kukri", "Niima's-embrace", "sica", "wakizashi"],
            :damage_types  => [33.3, 33.3, 33.3],
            :damage_factor => [0.350, 0.240, 0.200, 0.150, 0.125],
            #               Cloth  / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [40, 36, 35, 34, 33, 30, 28, 26, 24, 25, 21, 17, 13, 25, 19, 13, 7],
            :base_rt       => 3,
            :min_rt        => 3,
          },
        ]

        # Finds the weapon's stats hash by one of its names.
        #
        # @param name [String] The name or alias of the weapon.
        # @return [Hash, nil] The stats hash of the matching weapon, or nil if not found.
        def self.find_type_by_name(name)
          _, weapon_info = @@weapon_stats.find { |_, stats| stats[:all_names].include?(name) }
          return weapon_info
        end

        # Finds the weapon's category by one of its alternative names.
        #
        # @param name [String] The name or alias of the weapon.
        # @return [Symbol, nil] The weapon's category if found, otherwise nil.
        def self.find_category_by_name(name)
          _, weapon_info = @@weapon_stats.find { |_, stats| stats[:all_names].include?(name) }
          return weapon_info ? weapon_info[:category] : nil
        end
      end
    end
  end
end
