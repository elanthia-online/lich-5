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
#  Cloth:   [1] ASG 1    [2] ASG 2      [3] nil      [4] nil
#  Leather: [5] ASG 5    [6] ASG 6    [7] ASG 7    [8] ASG 8
#  Scale:   [9] ASG 9    [10] ASG 10  [11] ASG 11  [12] ASG 12
#  Chain:   [13] ASG 13  [14] ASG 14  [15] ASG 15  [16] ASG 16
#  Plate:   [17] ASG 17  [18] ASG 18  [19] ASG 19  [20] ASG 20
#

=begin Template
        :Name   => {
            :category      => :two_handed,
            :base_name     => "Name",
            :all_names     => ["Name", "Alt", "Alt", "Alt"],
            :damage_types  => [50, 16.7, 33.3],
            :damage_factor => [nil, 0.310, 0.225, 0.240, 0.125, 0.150],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 38, 38, nil, nil, 38, 37, 36, 35, 34, 32, 30, 28, 38, 34, 30, 26, 34, 28, 22, 16],
            :base_rt       => 5,
            :min_rt        => 4,
          },
=end
        @@weapon_stats_two_handed = [
          :bastard_sword => {
            :category      => :two_handed,
            :base_name     => "bastard sword",
            :all_names     => ["bastard sword", "cresset sword", "espadon", "war sword"],
            :damage_types  => [66.7, 33.3, 0.0],
            :damage_factor => [nil, 0.550, 0.400, 0.375, 0.300, 0.225],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 42, 42, nil, nil, 45, 44, 43, 42, 41, 39, 37, 35, 44, 40, 36, 32, 43, 37, 31, 25],
            :base_rt       => 6,
            :min_rt        => 4,
          },
          :katana        => {
            :category         => :two_handed,
            :base_name        => "katana",
            :all_names        => ["katana"],
            :damage_types     => [100, 0.0, 0.0],
            :damage_factor    => [nil, 0.575, 0.425, 0.400, 0.325, 0.210],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg       => [nil, 39, 39, nil, nil, 41, 40, 39, 38, 40, 38, 36, 34, 41, 37, 33, 29, 39, 33, 27, 21],
            :base_rt          => 6,
            :min_rt           => 4,
            :weighting_type   => :critical,
            :weighting_amount => 10
          },
        ]
      end
    end
  end
end
