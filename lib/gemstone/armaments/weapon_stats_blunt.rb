module Lich
  module Gemstone
    module Armaments
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
#

=begin Template
        :Name   => {
            :category      => :unarmed,
            :base_name     => "Name",
            :all_names     => ["Name", "Alt", "Alt", "Alt"],
            :damage_types  => [slash: 50.0, crush: 16.7, puncture: 33.3, special: [:none]],
            :damage_factor => [nil, 0.310, 0.225, 0.240, 0.125, 0.150],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 38, 38, nil, nil, 38, 37, 36, 35, 34, 32, 30, 28, 38, 34, 30, 26, 34, 28, 22, 16],
            :base_rt       => 5,
            :min_rt        => 4,
          },
=end
        @@weapon_stats_blunt = [
          :ball_and_chain => {
            :category      => :blunt,
            :base_name     => "ball and chain",
            :all_names     => ["ball and chain", "binnol", "goupillon", "mace and chain"],
            :damage_types  => [slash: 0.0, crush: 100.0, puncture: 0.0, special: [:none]],
            :damage_factor => [nil, 0.400, 0.300, 0.230, 0.260, 0.180],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 15, 15, nil, nil, 20, 19, 18, 17, 27, 25, 23, 21, 35, 31, 27, 23, 30, 24, 18, 12],
            :base_rt       => 6,
            :min_rt        => 4,
          },
          :crowbill       => {
            :category      => :blunt,
            :base_name     => "crowbill",
            :all_names     => ["crowbill", "hakapik", "skull-piercer"],
            :damage_types  => [slash: 0.0, crush: 50.0, puncture: 50.0, special: [:none]],
            :damage_factor => [nil, 0.350, 0.250, 0.200, 0.150, 0.125],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 40, 40, nil, nil, 36, 35, 34, 33, 30, 28, 26, 24, 30, 26, 22, 18, 20, 14, 8, 2],
            :base_rt       => 3,
            :min_rt        => 3
          },
          :cudgel         => {
            :category      => :blunt,
            :base_name     => "cudgel",
            :all_names     => ["cudgel", "aklys", "baculus", "club", "jo stick", "lisan", "periperiu", "shillelagh", "tambara", "truncheon", "waihaka", "war club"],
            :damage_types  => [slash: 0.0, crush: 100.0, puncture: 0.0, special: [:none]],
            :damage_factor => [nil, 0.350, 0.275, 0.200, 0.225, 0.150],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 20, 20, nil, nil, 20, 19, 18, 17, 25, 23, 21, 19, 25, 21, 17, 13, 30, 24, 18, 12],
            :base_rt       => 4,
            :min_rt        => 4,
          },
          :leather_whip   => {
            :category      => :blunt,
            :base_name     => "leather whip",
            :all_names     => ["leather whip", "bullwhip", "cat o' nine tails", "signal whip", "single-tail whip", "training whip", "whip"],
            :damage_types  => [slash: 0.0, crush: 100.0, puncture: 0.0, special: [:none]],
            :damage_factor => [nil, 0.275, 0.150, 0.090, 0.100, 0.035],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 35, 35, nil, nil, 25, 24, 23, 22, 20, 18, 16, 14, 25, 21, 17, 13, 15, 9, 3, -3],
            :base_rt       => 2,
            :min_rt        => 3,
          },
          :mace           => {
            :category      => :blunt,
            :base_name     => "mace",
            :all_names     => ["mace", "bulawa", "dhara", "flanged mace", "knee-breaker", "massuelle", "mattina", "nifa otti", "ox mace", "pernat", "quadrelle", "ridgemace", "studded mace"],
            :damage_types  => [slash: 0.0, crush: 100.0, puncture: 0.0, special: [:none]],
            :damage_factor => [nil, 0.400, 0.300, 0.225, 0.250, 0.175],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 31, 31, nil, nil, 32, 31, 30, 29, 35, 33, 31, 29, 42, 38, 34, 30, 36, 30, 24, 18],
            :base_rt       => 4,
            :min_rt        => 4,
          },
          :morning_star   => {
            :category      => :blunt,
            :base_name     => "morning star",
            :all_names     => ["morning star", "spiked mace", "holy water sprinkler", "spikestar"],
            :damage_types  => [slash: 0.0, crush: 66.7, puncture: 33.3, special: [:none]],
            :damage_factor => [nil, 0.425, 0.325, 0.275, 0.300, 0.225],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 33, 33, nil, nil, 35, 34, 33, 32, 34, 32, 30, 28, 42, 38, 34, 30, 37, 31, 25, 19],
            :base_rt       => 5,
            :min_rt        => 4,
          },
          :war_hammer     => {
            :category      => :blunt,
            :base_name     => "war hammer",
            :all_names     => ["war hammer", "fang", "hammerbeak", "hoolurge", "horseman's hammer", "skull-crusher", "taavish"],
            :damage_types  => [slash: 0.0, crush: 66.7, puncture: 33.3, special: [:none]],
            :damage_factor => [nil, 0.410, 0.290, 0.250, 0.275, 0.200],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 25, 25, nil, nil, 30, 29, 28, 27, 32, 30, 28, 26, 41, 37, 33, 29, 37, 31, 25, 19],
            :base_rt       => 4,
            :min_rt        => 4,
          },
        ]
      end
    end
  end
end
