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
        @@weapon_stats_natural = {
          :bite       => {
            :category      => :natural,
            :base_name     => "bite",
            :all_names     => ["bite"],
            :damage_types  => [slash: nil, crush: nil, puncture: nil, special: nil],
            :damage_factor => [nil, 0.400, 0.375, 0.375, 0.325, 0.300],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 39, 39, nil, nil, 39, 35, 34, 33, 32, 30, 28, 26, 24, 32, 28, 24, 20, 25, 19, 13, 7],
            :base_rt       => 5,
            :min_rt        => 5,
          },
          :charge     => {
            :category      => :natural,
            :base_name     => "charge",
            :all_names     => ["charge"],
            :damage_types  => [slash: 0.0, crush: nil, puncture: 0.0, special: [:unbalance]],
            :damage_factor => [nil, 0.175, 0.175, 0.150, 0.175, 0.150],
            #                        /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 26, 26, nil, nil, 32, 31, 30, 29, 41, 39, 37, 35, 37, 33, 29, 25, 49, 43, 37, 31],
            :base_rt       => 5,
            :min_rt        => 5,
          },
          :claw       => {
            :category      => :natural,
            :base_name     => "claw",
            :all_names     => ["claw"],
            :damage_types  => [slash: nil, crush: nil, puncture: nil, special: nil],
            :damage_factor => [nil, 0.225, 0.200, 0.200, 0.175, 0.175],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 41, 41, nil, nil, 38, 37, 36, 35, 29, 27, 25, 23, 31, 27, 23, 19, 25, 19, 13, 7],
            :base_rt       => 5,
            :min_rt        => 5,
          },
          :ensnare    => {
            :category      => :natural,
            :base_name     => "ensnare",
            :all_names     => ["ensnare"],
            :damage_types  => [slash: nil, crush: nil, puncture: nil, special: [:grapple]],
            :damage_factor => [nil, 0.275, 0.225, 0.200, 0.175, 0.150],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 25, 25, nil, nil, 31, 30, 29, 28, 40, 38, 36, 34, 38, 34, 30, 26, 50, 44, 38, 32],
            :base_rt       => 5,
            :min_rt        => 5,
          },
          :impale     => {
            :category      => :natural,
            :base_name     => "impale",
            :all_names     => ["impale"],
            :damage_types  => [slash: 0.0, crush: nil, puncture: nil, special: [:unbalance]],
            :damage_factor => [nil, 0.325, 0.315, 0.300, 0.285],
            #                       /Cloth             / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 37, 37, nil, nil, 43, 42, 41, 40, 33, 31, 29, 27, 35, 31, 27, 23, 31, 25, 19, 13],
            :base_rt       => 5,
            :min_rt        => 5,
          },
          :nip        => {
            :category      => :natural,
            :base_name     => "nip",
            :all_names     => ["nip"],
            :damage_types  => [slash: 0.0, crush: 0.0, puncture: nil, special: nil],
            :damage_factor => [nil, 0.125, 0.105, 0.090, 0.090, 0.100],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 35, 35, nil, nil, 40, 39, 38, 37, 25, 23, 21, 19, 28, 24, 20, 16, 20, 14, 8, 2],
            :base_rt       => 5,
            :min_rt        => 5,
          },
          :pincer     => {
            :category      => :natural,
            :base_name     => "pincer",
            :all_names     => ["pincer"],
            :damage_types  => [slash: nil, crush: nil, puncture: 0.0, special: nil],
            :damage_factor => [nil, 0.300, 0.300, 0.225, 0.225, 0.225],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 37, 37, nil, nil, 35, 34, 33, 32, 30, 28, 26, 24, 34, 30, 26, 22, 30, 24, 18, 12],
            :base_rt       => 5,
            :min_rt        => 5,
          },
          :pound      => {
            :category      => :natural,
            :base_name     => "pound",
            :all_names     => ["pound"],
            :damage_types  => [slash: 0.0, crush: 100.0, puncture: 0.0, special: nil],
            :damage_factor => [nil, 0.425, 0.350, 0.325, 0.325, 0.275],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 38, 38, nil, nil, 45, 44, 43, 42, 46, 44, 42, 40, 50, 46, 42, 38, 50, 44, 38, 32],
            :base_rt       => 5,
            :min_rt        => 5,
          },
          :stinger    => {
            :category      => :natural,
            :base_name     => "stinger",
            :all_names     => ["stinger"],
            :damage_types  => [slash: 0.0, crush: 0.0, puncture: 100.0, special: nil],
            :damage_factor => [nil, 0.110, 0.100, 0.100, 0.090, 0.085],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 43, 43, nil, nil, 30, 29, 28, 27, 25, 23, 21, 19, 28, 24, 20, 16, 20, 14, 8, 2],
            :base_rt       => 5,
            :min_rt        => 5,
          },
          :stomp      => {
            :category      => :natural,
            :base_name     => "stomp",
            :all_names     => ["stomp"],
            :damage_types  => [slash: 0.0, crush: 100.0, puncture: 0.0, special: nil],
            :damage_factor => [nil, 0.325, 0.325, 0.250, 0.225, 0.225],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 39, 39, nil, nil, 45, 44, 43, 42, 35, 33, 31, 29, 45, 41, 37, 33, 33, 27, 21, 15],
            :base_rt       => 5,
            :min_rt        => 5,
          },
          :tail_swing => {
            :category      => :natural,
            :base_name     => "tail swing",
            :all_names     => ["tail swing"],
            :damage_types  => [slash: 0.0, crush: 100.0, puncture: 0.0, special: nil],
            :damage_factor => [nil, 0.400, 0.300, 0.225, 0.250, 0.175],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 31, 31, nil, nil, 32, 31, 30, 29, 35, 33, 31, 29, 42, 38, 34, 30, 36, 30, 24, 18],
            :base_rt       => 5,
            :min_rt        => 5,
          },
        ]
      end
    end
  end
end
