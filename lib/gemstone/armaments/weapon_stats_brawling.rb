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
            :category      => :brawling,
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
        @@weapon_stats_brawling = [
          :closed_fist => {
            :category      => :brawling,
            :base_name     => "closed fist",
            :all_names     => ["closed fist"],
            :damage_types  => [0.0, 100.0, 0.0],
            :damage_factor => [nil, 0.100, 0.075, 0..40, 0.036, 0.032],
            #                       /Cloth            / Leather       / Scale      / Chain       / Plate
            :avd_by_asg    => [nil, 25, 25, nil, nil, 20, 19, 18, 17, 10, 8, 6, 4, 5, 1, -3, -7, -5, -11, -17, -23],
            :base_rt       => 1,
            :min_rt        => 2,
          },
          :blackjack   => {
            :category      => :brawling,
            :base_name     => "blackjack",
            :all_names     => ["blackjack", "bludgeon", "sap"],
            :damage_types  => [0.0, 100.0, 0.0],
            :damage_factor => [nil, 0.250, 0.140, 0.090, 0.110, 0.075],
            #                       /Cloth            / Leather       / Scale         / Chain       / Plate
            :avd_by_asg    => [nil, 40, 40, nil, nil, 35, 34, 33, 32, 25, 23, 21, 19, 15, 11, 7, 3, 0, -6, -12, -18],
            :base_rt       => 1,
            :min_rt        => 2,
          },
          :cestus      => {
            :category      => :brawling,
            :base_name     => "cestus",
            :all_names     => ["cestus"],
            :damage_types  => [0.0, 100.0, 0.0],
            :damage_factor => [nil, 0.250, 0.175, 0.150, 0.075, 0.035],
            #                       /Cloth            / Leather       / Scale         / Chain       / Plate
            :avd_by_asg    => [nil, 40, 40, nil, nil, 30, 29, 28, 27, 20, 18, 16, 14, 10, 6, 2, -2, -25, -31, -37, -43],
            :base_rt       => 1,
            :min_rt        => 2,
          },
          :fist_scythe => {
            :category      => :brawling,
            :base_name     => "fist-scythe",
            :all_names     => ["fist-scythe", "hand-hook", "hook", "hook-claw", "kama", "sickle"],
            :damage_types  => [66.7, 16.7, 16.6],
            :damage_factor => [nil, 0.350, 0.225, 0.200, 0.175, 0.125],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 45, 45, nil, nil, 40, 39, 38, 37, 30, 28, 26, 24, 37, 33, 29, 25, 20, 14, 8, 2],
            :base_rt       => 3,
            :min_rt        => 3,
          },

        ]
      end
    end
  end
end
