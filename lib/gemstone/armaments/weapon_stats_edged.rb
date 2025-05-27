module Lich
  module Gemstone
    module Armaments
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
        @@weapon_stats_edged = [
          # OHE Weapons
          :arrow       => { # when swung, not when fired
            :category      => :edged,
            :base_name     => "arrow",
            :all_names     => ["sitka", "arrow"],
            :damage_types  => [33.3, 0.0, 66.7],
            :damage_factor => [nil, 0.200, 0.100, 0.080, 0.100, 0.040],
            #                       /Cloth             / Leather       / Scale      / Chain       / Plate
            :avd_by_asg    => [nil, 20, nil, nil, nil, 18, 17, 16, 15, 10, 8, 6, 4, 5, 1, -3, -7, -5, -11, -17, -23],
            :base_rt       => 5,
            :min_rt        => 4,
          },
          :dagger      => {
            :category      => :edged,
            :base_name     => "dagger",
            :all_names     => ["alfange", "basilard", "bodice dagger", "bodkin", "boot dagger", "bracelet dagger", "butcher knife", "cinquedea", "crescent dagger", "dagger", "dirk", "fantail dagger", "forked dagger", "gimlet knife", "kaiken", "kidney dagger", "knife", "kozuka", "krizta", "kubikiri", "misericord", "parazonium", "pavade", "poignard", "pugio", "push dagger", "scramasax", "sgian achlais", "sgian dubh", "sidearm-of-Onar", "spike", "stiletto", "tanto", "trail knife", "trailknife", "zirah bouk"],
            :damage_types  => [33.3, 0.0, 66.7],
            :damage_factor => [nil, 0.250, 0.200, 0.100, 0.125, 0.075],
            #                       /Cloth             / Leather       / Scale      / Chain       / Plate
            :avd_by_asg    => [nil, 25, nil, nil, nil, 23, 22, 21, 20, 15, 13, 11, 9, 10, 6, 2, -2, 0, -6, -12, -18],
            :base_rt       => 1,
            :min_rt        => 2,
          },
          :main_gauche => {
            :category      => :edged,
            :base_name     => "main gauche",
            :all_names     => ["parrying dagger", "main gauche", "shield-sword", "sword-breaker"],
            :damage_types  => [33.3, 0.0, 66.7],
            :damage_factor => [nil, 0.275, 0.210, 0.110, 0.125, 0.075],
            #                       /Cloth             / Leather       / Scale      / Chain       / Plate
            :avd_by_asg    => [nil, 27, nil, nil, nil, 25, 24, 23, 22, 20, 18, 16, 14, 20, 16, 12, 8, 20, 14, 8, 2],
            :base_rt       => 2,
            :min_rt        => 3,
          },
          :rapier      => {
            :category      => :edged,
            :base_name     => "rapier",
            :all_names     => ["bilbo", "colichemarde", "epee", "fleuret", "foil", "rapier", "schlager", "tizona", "tock", "tocke", "tuck", "verdun"],
            :damage_types  => [33.3, 0.0, 66.7],
            :damage_factor => [nil, 0.325, 0.225, 0.125, 0.125, 0.075],
            #                       /Cloth             / Leather       / Scale      / Chain       / Plate
            :avd_by_asg    => [nil, 45, nil, nil, nil, 40, 39, 38, 37, 30, 28, 26, 24, 35, 31, 27, 23, 15, 9, 3, -3],
            :base_rt       => 2,
            :min_rt        => 3,
          },
          :whip_blade  => {
            :category      => :edged,
            :base_name     => "whip-blade",
            :all_names     => ["whip-blade", "whipblade"],
            :damage_types  => [100.0, 0.0, 0.0],
            :damage_factor => [nil, 0.333, 0.225, 0.125, 0.115, 0.065],
            #                       /Cloth             / Leather       / Scale      / Chain       / Plate
            :avd_by_asg    => [nil, 45, nil, nil, nil, 40, 39, 38, 37, 30, 28, 26, 24, 35, 31, 27, 23, 15, 9, 3, -3],
            :base_rt       => 2,
            :min_rt        => 3,
          },
          :short_sword => {
            :category      => :edged,
            :base_name     => "short sword",
            :all_names     => ["acinaces", "antler sword", "backslasher", "braquemar", "baselard", "chereb", "coustille", "gladius", "gladius graecus", "kris", "kukri", "Niima's-embrace", "sica", "wakizashi"],
            :damage_types  => [33.3, 33.3, 33.3],
            :damage_factor => [nil, 0.350, 0.240, 0.200, 0.150, 0.125],
            #                       /Cloth             / Leather       / Scale      / Chain       / Plate
            :avd_by_asg    => [nil, 40, nil, nil, nil, 36, 35, 34, 33, 30, 28, 26, 24, 25, 21, 17, 13, 25, 19, 13, 7],
            :base_rt       => 3,
            :min_rt        => 3,
          },
        ]
      end
    end
  end
end
