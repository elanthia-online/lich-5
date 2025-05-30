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
        @@weapon_stats_runestave = [
          :runestave => {
            :category      => :runestave,
            :base_name     => "runestave",
            :all_names     => ["runestave", "asaya", "crook", "crosier", "pastoral staff", "rune staff", "runestaff", "scepter", "scepter-of-Lumnis", "staff", "staff-of-lumnis", "walking stick"],
            :damage_types  => [slash: 0.0, crush: 100.0, puncture: 0.0, special: [:none]],
            :damage_factor => [nil, 0.250, 0.200, 0.150, 0.150, 0.075],
            #                       /Cloth            / Leather       / Scale      / Chain       / Plate
            :avd_by_asg    => [nil, 10, 10, nil, nil, 15, 14, 13, 12, 10, 8, 6, 4, 15, 11, 7, 3, 10, 4, -2, -8],
            :base_rt       => 6,
            :min_rt        => 4,
          },
        ]
      end
    end
  end
end
