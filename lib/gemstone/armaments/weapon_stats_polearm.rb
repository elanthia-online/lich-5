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
            :damage_types  => [slash: 50.0, crush: 16.7, puncture: 33.3, special: []],
            :damage_factor => [nil, 0.310, 0.225, 0.240, 0.125, 0.150],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 38, 38, nil, nil, 38, 37, 36, 35, 34, 32, 30, 28, 38, 34, 30, 26, 34, 28, 22, 16],
            :base_rt       => 5,
            :min_rt        => 4,
          },
=end
        @@weapon_stats_polearm = {
          :awl_pike      => {
            :category      => :polearm,
            :base_name     => "awl-pike",
            :all_names     => ["awl-pike", "ahlspiess", "breach pike", "chest-ripper", "korseke", "military fork", "ranseur", "runka", "scaling fork", "spetum"],
            :damage_types  => [slash: 0.0, crush: 13.0, puncture: 87.0, special: []],
            :damage_factor => [nil, 0.600, 0.550, 0.575, 0.450, 0.350],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 15, 15, nil, nil, 20, 19, 18, 17, 35, 33, 21, 29, 45, 41, 37, 33, 50, 44, 38, 32],
            :base_rt       => 9,
            :min_rt        => 4,
          },
          :halberd       => {
            :category      => :polearm,
            :base_name     => "halberd",
            :all_names     => ["halberd", "atgeir", "bardiche", "bill", "brandestoc", "croc", "falcastra", "fauchard", "glaive", "godendag", "guisarme", "half moon", "half-moon", "hippe", "kerambit", "pole axe", "pole-axe", "scorpion", "scythe"],
            :damage_types  => [slash: 33.3, crush: 33.3, puncture: 33.3, special: []],
            :damage_factor => [nil, 0.550, 0.400, 0.400, 0.300, 0.200],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 30, 30, nil, nil, 30, 29, 28, 17, 31, 29, 27, 25, 32, 28, 24, 20, 32, 26, 20, 14],
            :base_rt       => 6,
            :min_rt        => 4,
          },
          :hammer_of_kai => {
            :category      => :polearm,
            :base_name     => "Hammer of Kai",
            :all_names     => ["Hammer of Kai", "bovai", "longhammer", "polehammer", "spiked-hammer"],
            :damage_types  => [slash: 0.0, crush: nil, puncture: nil, special: []], # data missing from wiki
            :damage_factor => [nil, 0.550, 0.425, 0.450, 0.350, 0.250],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 20, 20, nil, nil, 25, 24, 23, 22, 35, 33, 31, 29, 40, 36, 32, 28, 40, 34, 28, 22],
            :base_rt       => 7,
            :min_rt        => 4,
          },
          :jeddart_axe   => {
            :category      => :polearm,
            :base_name     => "jeddart-axe",
            :all_names     => ["jeddart-axe", "beaked axe", "nagimaki", "poleaxe", "voulge"],
            :damage_types  => [slash: 50.0, crush: 50.0, puncture: 0.0, special: []],
            :damage_factor => [nil, 0.550, 0.425, 0.425, 0.325, 0.250],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 30, 30, nil, nil, 32, 31, 30, 29, 30, 28, 26, 24, 40, 36, 32, 28, 30, 24, 18, 12],
            :base_rt       => 7,
            :min_rt        => 4,
          },
          :javelin       => {
            :category      => :polearm,
            :base_name     => "javelin",
            :all_names     => ["javelin", "contus", "jaculum", "knopkierie", "lancea", "nage-yari", "pelta", "shail", "spiculum"],
            :damage_types  => [slash: 17.0, crush: 0.0, puncture: 83.0, special: []],
            :damage_factor => [nil, 0.402, 0.304, 0.254, 0.254, 0.102],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 27, 27, nil, nil, 28, 27, 25, 25, 26, 24, 22, 20, 29, 25, 21, 17, 20, 14, 8, 2],
            :base_rt       => 4,
            :min_rt        => 5,
          },
          :lance         => {
            :category      => :polearm,
            :base_name     => "lance",
            :all_names     => ["lance", "framea", "pike", "sarissa", "sudis", "warlance", "warpike"],
            :damage_types  => [slash: 0.0, crush: 33.0, puncture: 67.0, special: []],
            :damage_factor => [nil, 0.725, 0.525, 0.559, 0.475, 0.350],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 35, 35, nil, nil, 38, 37, 36, 35, 39, 37, 35, 33, 53, 49, 45, 31, 50, 44, 38, 32],
            :base_rt       => 9,
            :min_rt        => 4,
          },
          :naginata      => {
            :category      => :polearm,
            :base_name     => "naginata",
            :all_names     => ["naginata", "swordstaff", "bladestaff"],
            :damage_types  => [slash: 33.3, crush: 33.3, puncture: 33.3, special: []],
            :damage_factor => [nil, 0.550, 0.400, 0.400, 0.300, 0.200],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 50, 50, nil, nil, 50, 49, 48, 27, 51, 49, 47, 45, 52, 48, 44, 40, 52, 46, 40, 34],
            :base_rt       => 6,
            :min_rt        => 4,
          },
          :pilum         => {
            :category      => :polearm,
            :base_name     => "pilum",
            :all_names     => ["pilum"],
            :damage_types  => [slash: 17.0, crush: 0.0, puncture: 83.0, special: []],
            :damage_factor => [nil, 0.350, 0.250, 0.225, 0.175, 0.060],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 30, 30, nil, nil, 27, 26, 25, 24, 22, 20, 18, 16, 23, 19, 15, 11, 15, 9, 3, -3],
            :base_rt       => 3,
            :min_rt        => 3,
          },
          :spear         => {
            :category      => :polearm,
            :base_name     => "spear",
            :all_names     => ["angon", "atlatl", "boar spear", "cateia", "dory", "falarica", "gaesum", "gaizaz", "harpoon", "hasta", "partisan", "partizan", "pill spear", "spontoon", "verutum", "yari"],
            :damage_types  => [slash: 17.0, crush: 0.0, puncture: 83.0, special: []],
            # spear can be used 1 or 2 handed, using the same skill, arrays returned for data below are 0 = one handed, and 1 = two handed
            :damage_factor => [[nil, 0.425, 0.325, 0.250, 0.250, 0.160], [nil, 0.550, 0.225, 0.240, 0.125, 0.150]],
            #                        /Cloth            / Leather       / Scale         / Chain         / Plate               /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [[nil, 27, 27, nil, nil, 29, 28, 27, 26, 27, 25, 23, 21, 30, 26, 22, 18, 25, 19, 13, 7], [nil, 33, 33, nil, nil, 32, 31, 30, 29, 34, 32, 30, 28, 36, 32, 28, 24, 33, 27, 21, 15]],
            :base_rt       => [5, 6],
            :min_rt        => 4,
            :gripable?     => true,
          },
          :trident       => {
            :category      => :polearm,
            :base_name     => "trident",
            :all_names     => ["trident", "fuscina", "magari-yari", "pitch fork", "pitchfork", "zinnor"],
            :damage_types  => [slash: 33.0, crush: 0.0, puncture: 67.0, special: []],
            # trident can be used 1 or 2 handed, using the same skill, arrays returned for data below are 0 = one handed, and 1 = two handed
            :damage_factor => [[nil, 0.425, 0.350, 0.260, 0.230, 0.150], [nil, 0.600, 0.425, 0.375, 0.300, 0.185]],
            #                        /Cloth            / Leather       / Scale         / Chain         / Plate                /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [[nil, 31, 31, nil, nil, 31, 30, 29, 28, 34, 32, 30, 28, 42, 38, 34, 30, 29, 23, 17, 11], [nil, 29, 29, nil, nil, 30, 29, 28, 27, 30, 28, 26, 24, 37, 33, 29, 25, 25, 19, 13, 7]],
            :base_rt       => [5, 6],
            :min_rt        => 4,
            :gripable?     => true,
          },
        }
      end
    end
  end
end
