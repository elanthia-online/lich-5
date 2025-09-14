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
#   :special  => Array of special damage types (or empty array)
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
            :damage_types  => { slash: 50.0, crush: 16.7, puncture: 33.3, special: [:unbalance] },
            :damage_factor => [nil, 0.310, 0.225, 0.240, 0.125, 0.150],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 38, 38, nil, nil, 38, 37, 36, 35, 34, 32, 30, 28, 38, 34, 30, 26, 34, 28, 22, 16],
            :base_rt       => 5,
            :min_rt        => 4,
          },
=end
        @@weapon_stats_thrown = {
          :bola         => {
            :category      => :thrown,
            :base_name     => "bola",
            :all_names     => ["bola", "bolas", "boleadoras", "kurutai", "weighted-cord"],
            :damage_types  => { slash: 0.0, crush: 100.0, puncture: 0.0, special: [] },
            :damage_factor => [nil, 0.310, 0.225, 0.240, 0.125, 0.150],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 25, 25, nil, nil, 20, 19, 18, 17, 30, 28, 26, 24, 25, 21, 17, 13, 35, 29, 23, 17],
            :base_rt       => 5,
            :min_rt        => 2,
          },
          :dart         => {
            :category      => :thrown,
            :base_name     => "dart",
            :all_names     => ["dart", "nagyka"],
            :damage_types  => { slash: 0.0, crush: 0.0, puncture: 100.0, special: [] },
            :damage_factor => [nil, 0.125, 0.100, 0.075, 0.055, 0.050],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 35, 35, nil, nil, 30, 29, 28, 27, 25, 23, 21, 19, 20, 16, 12, 8, 10, 4, -2, -8],
            :base_rt       => 2,
            :min_rt        => 3,
          },
          :discus       => {
            :category      => :thrown,
            :base_name     => "discus",
            :all_names     => ["discus", "throwing disc", "disc"],
            :damage_types  => { slash: 0.0, crush: 100.0, puncture: 0.0, special: [] },
            :damage_factor => [nil, 0.255, 0.230, 0.155, 0.110, 0.057],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 40, 40, nil, nil, 35, 34, 33, 32, 30, 28, 26, 24, 25, 21, 17, 13, 30, 24, 18, 12],
            :base_rt       => 5,
            :min_rt        => 2,
          },
          :javelin      => {
            :category      => :thrown,
            :base_name     => "javelin",
            :all_names     => ["javelin", "contus", "jaculum", "knopkierie", "lancea", "nage-yari", "pelta", "shail", "spiculum"],
            :damage_types  => { slash: 0.0, crush: 0.0, puncture: 100.0, special: [] },
            :damage_factor => [nil, 0.400, 0.300, 0.250, 0.250, 0.100],
            #                       /Cloth  / Leather / Scale   / Chain   / Plate
            :avd_by_asg    => [nil, 27, 27, nil, nil, 28, 27, 25, 25, 26, 24, 22, 20, 29, 25, 21, 17, 20, 14, 8, 2],
            :base_rt       => 4,
            :min_rt        => 3,
          },
          :throwing_net => {
            :category      => :thrown,
            :base_name     => "throwing net",
            :all_names     => ["throwing net"],
            :damage_types  => { slash: 0.0, crush: 0.0, puncture: 0.0, special: [:unbalance] },
            :damage_factor => [nil, 0.050, 0.050, 0.030, 0.030, 0.010],
            #                       /Cloth             / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 25, 25, nil, nil, 25, 24, 23, 22, 30, 28, 26, 24, 40, 36, 32, 28, 50, 44, 38, 32],
            :base_rt       => 7,
            :min_rt        => 3,
          },
          :quoit        => {
            :category      => :thrown,
            :base_name     => "quoit",
            :all_names     => ["quoit", "bladed-ring", "bladed-disc", "bladed wheel", "battle-quoit", "chakram", "war-quoit"],
            :damage_types  => { slash: 100.0, crush: 0.0, puncture: 0.0, special: [] },
            :damage_factor => [nil, 0.255, 0.230, 0.155, 0.110, 0.057],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 40, 40, nil, nil, 35, 34, 33, 32, 30, 28, 26, 24, 25, 21, 17, 13, 30, 24, 18, 12],
            :base_rt       => 5,
            :min_rt        => 3,
          },
          :handaxe      => {
            :category      => :edged,
            :base_name     => "handaxe",
            :all_names     => ["handaxe", "balta", "boarding axe", "broad axe", "cleaver", "crescent axe", "double-bit axe", "field-axe", "francisca", "hatchet", "hunting axe", "hunting hatchet", "ice axe", "limb-cleaver", "logging axe", "meat cleaver", "miner's axe", "moon axe", "ono", "raiding axe", "sparte", "splitting axe", "throwing axe", "taper", "tomahawk", "toporok", "waraxe"],
            :damage_types  => { slash: 33.3, crush: 66.7, puncture: 0.0, special: [] },
            :damage_factor => [nil, 0.420, 0.300, 0.270, 0.240, 0.210],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 30, 30, nil, nil, 32, 31, 30, 29, 38, 36, 34, 32, 41, 37, 33, 29, 41, 35, 29, 23],
            :base_rt       => 5,
            :min_rt        => 4,
          },
        }
      end
    end
  end
end
