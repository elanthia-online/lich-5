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
        @@weapon_stats_ranged = {
          :composite_bow  => {
            :category      => :ranged,
            :base_name     => "composite bow",
            :all_names     => ["composite bow", "composite recurve bow", "lutk'azi"],
            :damage_types  => [slash: 66.6, crush: 0.0, puncture: 33.7, special: [:none]],
            :damage_factor => [nil, 0.350, 0.300, 0.325, 0.275, 0.150],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 25, 25, nil, nil, 35, 34, 33, 32, 30, 28, 26, 24, 42, 38, 34, 30, 36, 30, 24, 18],
            :base_rt       => 6,
            :min_rt        => 3,
            :weapon_class  => :bow
          },
          :hand_crossbow  => {
            :category      => :ranged,
            :base_name     => "hand crossbow",
            :all_names     => ["hand crossbow"],
            :damage_types  => [slash: 66.6, crush: 0.0, puncture: 33.7, special: [:none]],
            :damage_factor => [nil, 0.275, 0.225, 0.250, 0.190, 0.135],
            :avd_by_asg    => [nil, 20, 20, nil, nil, 26, 25, 24, 23, 20, 18, 16, 14, 34, 30, 26, 22, 27, 21, 15, 9],
            :base_rt       => 4,
            :min_rt        => 4,
            :weapon_class  => :crossbow
          },
          :heavy_crossbow => {
            :category      => :ranged,
            :base_name     => "heavy crossbow",
            :all_names     => ["heavy crossbow", "heavy arbalest", "kut'ziko", "repeating crossbow", "siege crossbow"],
            :damage_types  => [slash: 66.6, crush: 0.0, puncture: 33.7, special: [:none]],
            :damage_factor => [nil, 0.425, 0.325, 0.375, 0.285, 0.175],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 30, 30, nil, nil, 36, 35, 34, 33, 31, 29, 27, 25, 46, 42, 38, 34, 40, 34, 28, 22],
            :base_rt       => 7,
            :min_rt        => 5,
            :weapon_class  => :crossbow
          },
          :light_crossbow => {
            :category      => :ranged,
            :base_name     => "light crossbow",
            :all_names     => ["light crossbow", "kut'zikokra", "light arbalest"],
            :damage_types  => [slash: 66.6, crush: 0.0, puncture: 33.7, special: [:none]],
            :damage_factor => [nil, 0.350, 0.300, 0.325, 0.275, 0.150],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 25, 25, nil, nil, 31, 30, 29, 28, 25, 23, 21, 19, 39, 35, 31, 27, 32, 26, 20, 14],
            :base_rt       => 6,
            :min_rt        => 4,
            :weapon_class  => :crossbow
          },
          :long_bow       => {
            :category      => :ranged,
            :base_name     => "long bow",
            :all_names     => ["long bow", "long recurve bow", "longbow", "lutk'quoab", "yumi"],
            :damage_types  => [slash: 66.6, crush: 0.0, puncture: 33.7, special: [:none]],
            :damage_factor => [nil, 0.400, 0.325, 0.350, 0.300, 0.175],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 25, 25, nil, nil, 33, 32, 31, 30, 29, 27, 25, 23, 42, 38, 34, 30, 38, 32, 26, 20],
            :base_rt       => 7,
            :min_rt        => 3,
            :weapon_class  => :bow
          },
          :short_bow      => {
            :category      => :ranged,
            :base_name     => "short bow",
            :all_names     => ["short bow", "short recurve bow"],
            :damage_types  => [slash: 66.6, crush: 0.0, puncture: 33.7, special: [:none]],
            :damage_factor => [nil, 0.325, 0.225, 0.275, 0.250, 0.100],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 20, 20, nil, nil, 27, 26, 25, 24, 20, 18, 16, 14, 31, 27, 23, 19, 27, 21, 15, 9],
            :base_rt       => 5,
            :min_rt        => 3,
            :weapon_class  => :bow
          },
          :broadhead      => {
            :category      => :ranged,
            :base_name     => "broadhead",
            :all_names     => ["broadhead", "default", ""],
            :damage_types  => [slash: 66.6, crush: 0.0, puncture: 33.7, special: [:none]],
            :damage_factor => [nil, 0.0, 0.0, 0.0, 0.0, 0.0], # for ammunition, these are modifiers
            #                       /Cloth          / Leather   / Scale     / Chain     / Plate
            :avd_by_asg    => [nil, 0, 0, nil, nil, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # for ammunition, these are modifiers
            :base_rt       => 0, # for ammunition, this is a modifier, not a base RT
            :min_rt        => 0, # for ammunition, this is a modifier, not a minimum RT
            :weapon_class  => :ammunition
          },
          :blunt          => {
            :category      => :ranged,
            :base_name     => "blunt",
            :all_names     => ["blunt"],
            :damage_types  => [slash: 0.0, crush: 0.0, puncture: 0.0, special: [:unbalance]],
            :damage_factor => [nil, -0.050, -0.050, -0.050, -0.050, -0.050], # for ammunition, these are modifiers
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 10, 10, nil, nil, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10], # for ammunition, these are modifiers
            :base_rt       => 0, # for ammunition, this is a modifier, not a base RT
            :min_rt        => 0, # for ammunition, this is a modifier, not a minimum RT
            :weapon_class  => :ammunition,
          },
          :bodkin_point   => {
            :category      => :ranged,
            :base_name     => "bodkin point",
            :all_names     => ["bodkin point"],
            :damage_types  => [slash: 66.6, crush: 0.0, puncture: 33.7, special: [:none]],
            :damage_factor => [nil, -0.050, -0.025, -0.010, 0.025, 0.015], # for ammunition, these are modifiers
            #                       /Cloth          / Leather   / Scale     / Chain     / Plate
            :avd_by_asg    => [nil, 0, 0, nil, nil, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 5, 5, 5, 5, 5, 5], # for ammunition, these are modifiers
            :base_rt       => 0, # for ammunition, this is a modifier, not a base RT
            :min_rt        => 0, # for ammunition, this is a modifier, not a minimum RT
            :weapon_class  => :ammunition
          },
          :crescent       => {
            :category      => :ranged,
            :base_name     => "crescent",
            :all_names     => ["crescent"],
            :damage_types  => [slash: 83.6, crush: 0.0, puncture: 16.7, special: [:none]],
            :damage_factor => [nil, 0.0, 0.0, 0.0, 0.0, 0.0], # for ammunition, these are modifiers
            #                       /Cloth          / Leather   / Scale     / Chain     / Plate
            :avd_by_asg    => [nil, 0, 0, nil, nil, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # for ammunition, these are modifiers
            :base_rt       => 0, # for ammunition, this is a modifier, not a base RT
            :min_rt        => 0, # for ammunition, this is a modifier, not a minimum RT
            :weapon_class  => :ammunition
          },
        ]
      end
    end
  end
end
