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
        @@weapon_stats_hybrid = [
          # Hybrid Weapons
          "katar" => {
            :category      => :HYBRID,
            :hybrid_skills => [:OHE, :BRAWL],
            :base_name     => "katar",
            :all_names     => ["katar", "gauntlet-sword", "kunai", "manople", "paiscush", "pata", "slasher", "tvekre"],
            :damage_types  => [slash: 33.3, crush: 0.0, puncture: 66.7, special: [:none]],
            :damage_factor => [nil, 0.325, 0.250, 0.225, 0.200, 0.175],
            #                       /Cloth             / Leather       / Scale      / Chain       / Plate
            :avd_by_asg    => [nil, 30, nil, nil, nil, 32, 31, 30, 29, 40, 38, 36, 34, 45, 41, 37, 33, 40, 34, 28, 22],
            :base_rt       => 3,
            :min_rt        => 3,
          },
        ]
      end
    end
  end
end
