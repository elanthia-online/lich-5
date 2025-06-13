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
        @@weapon_stats_two_handed = {
          :bastard_sword    => {
            :category      => :two_handed,
            :base_name     => "bastard sword",
            :all_names     => ["bastard sword", "cresset sword", "espadon", "war sword"],
            :damage_types  => [slash: 66.7, crush: 33.3, puncture: 0.0, special: []],
            :damage_factor => [nil, 0.550, 0.400, 0.375, 0.300, 0.225],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 42, 42, nil, nil, 45, 44, 43, 42, 41, 39, 37, 35, 44, 40, 36, 32, 43, 37, 31, 25],
            :base_rt       => 6,
            :min_rt        => 4,
            :grippable?    => true,
          },
          :battle_axe       => {
            :category      => :two_handed,
            :base_name     => "battle axe",
            :all_names     => ["battle axe", "adze", "balestarius", "battle-axe", "bearded axe", "doloire", "executioner's axe", "greataxe", "hektov sket", "kheten", "roa'ter axe", "tabar", "woodsman's axe"],
            :damage_types  => [slash: 66.7, crush: 33.3, puncture: 0.0, special: []],
            :damage_factor => [nil, 0.650, 0.475, 0.500, 0.375, 0.275],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 35, 35, nil, nil, 39, 38, 37, 36, 43, 41, 39, 37, 50, 46, 42, 38, 50, 44, 38, 32],
            :base_rt       => 8,
            :min_rt        => 4,
          },
          :claidhmore       => { # made a choice here to only account for new style claidmores, not the old ones
            :category         => :two_handed,
            :base_name        => "claidhmore",
            :all_names        => ["claidhmore"],
            :damage_types     => [slash: 50.0, crush: 50.0, puncture: 0.0, special: []],
            :damage_factor    => [nil, 0.625, 0.475, 0.500, 0.350, 0.225],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg       => [nil, 31, 31, nil, nil, 35, 34, 33, 32, 34, 32, 30, 28, 38, 34, 30, 26, 37, 31, 25, 19],
            :base_rt          => 8,
            :min_rt           => 4,
            :weighting_type   => :critical,
            :weighting_amount => 40,
          },
          :flail            => {
            :category      => :two_handed,
            :base_name     => "flail",
            :all_names     => ["flail", "military flail", "spiked-staff"],
            :damage_types  => [slash: 0.0, crush: 66.7, puncture: 33.3, special: []],
            :damage_factor => [nil, 0.575, 0.425, 0.400, 0.350, 0.250],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 40, 40, nil, nil, 45, 44, 43, 42, 46, 44, 42, 40, 51, 47, 43, 39, 52, 46, 40, 34],
            :base_rt       => 7,
            :min_rt        => 4,
          },
          :flamberge        => {
            :category      => :two_handed,
            :base_name     => "flamberge",
            :all_names     => ["flamberge", "reaver", "wave-bladed sword", "sword-of-Phoen"],
            :damage_types  => [slash: 50.0, crush: 50.0, puncture: 0.0, special: []],
            :damage_factor => [nil, 0.600, 0.450, 0.475, 0.325, 0.225],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 39, 39, nil, nil, 43, 42, 41, 40, 48, 46, 44, 42, 50, 46, 42, 38, 44, 38, 32, 26],
            :base_rt       => 7,
            :min_rt        => 4,
          },
          :katana           => {
            :category         => :two_handed,
            :base_name        => "katana",
            :all_names        => ["katana"],
            :damage_types     => [slash: 100.0, crush: 0.0, puncture: 0.0, special: []],
            :damage_factor    => [nil, 0.575, 0.425, 0.400, 0.325, 0.210],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg       => [nil, 39, 39, nil, nil, 41, 40, 39, 38, 40, 38, 36, 34, 41, 37, 33, 29, 39, 33, 27, 21],
            :base_rt          => 6,
            :min_rt           => 4,
            :weighting_type   => :critical,
            :weighting_amount => 10,
            :grippable?       => true,
          },
          :maul             => {
            :category      => :two_handed,
            :base_name     => "maul",
            :all_names     => ["maul", "battle hammer", "footman's hammer", "sledgehammer", "tetsubo"],
            :damage_types  => [slash: 0.0, crush: 100.0, puncture: 0.0, special: []],
            :damage_factor => [nil, 0.550, 0.425, 0.425, 0.375, 0.300],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 31, 31, nil, nil, 36, 35, 34, 33, 44, 42, 40, 38, 52, 48, 44, 40, 54, 48, 42, 36],
            :base_rt       => 7,
            :min_rt        => 4,
          },
          :military_pick    => {
            :category      => :two_handed,
            :base_name     => "military pick",
            :all_names     => ["military pick", "bisacuta", "mining pick"],
            :damage_types  => [slash: 0.0, crush: 33.3, puncture: 66.7, special: []],
            :damage_factor => [nil, 0.500, 0.375, 0.425, 0.375, 0.260],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 25, 25, nil, nil, 30, 29, 28, 27, 40, 38, 36, 34, 40, 36, 32, 28, 47, 41, 35, 29],
            :base_rt       => 7,
            :min_rt        => 4,
          },
          :quarterstaff     => {
            :category      => :two_handed,
            :base_name     => "quarterstaff",
            :all_names     => ["quarterstaff", "bo stick", "staff", "toyak", "walking staff", "warstaff", "yoribo"],
            :damage_types  => [slash: 0.0, crush: 100.0, puncture: 0.0, special: []],
            :damage_factor => [nil, 0.450, 0.350, 0.325, 0.175, 0.100],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 25, 25, nil, nil, 26, 25, 24, 23, 25, 23, 21, 19, 26, 22, 18, 14, 24, 18, 12, 6],
            :base_rt       => 3,
            :min_rt        => 3,
          },
          :two_handed_sword => {
            :category      => :two_handed,
            :base_name     => "two-handed sword",
            :all_names     => ["two-handed sword", "battlesword", "beheading sword", "bidenhander", "falx", "executioner's sword", "greatsword", "mekya ne'rutka", "no-dachi", "zweihander"],
            :damage_types  => [slash: 50.0, crush: 50.0, puncture: 0.0, special: []],
            :damage_factor => [nil, 0.625, 0.500, 0.500, 0.350, 0.275],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 41, 41, nil, nil, 45, 44, 43, 42, 44, 42, 40, 38, 48, 44, 40, 36, 47, 41, 35, 29],
            :base_rt       => 8,
            :min_rt        => 4,
          },
          :war_mattock      => {
            :category      => :two_handed,
            :base_name     => "war mattock",
            :all_names     => ["war mattock", "mattock", "oncin", "pickaxe", "sabar"],
            :damage_types  => [slash: 0.0, crush: 100.0, puncture: 0.0, special: []],
            :damage_factor => [nil, 0.550, 0.450, 0.425, 0.375, 0.275],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 32, 32, nil, nil, 37, 36, 35, 34, 44, 42, 40, 38, 48, 44, 40, 36, 53, 47, 41, 35],
            :base_rt       => 7,
            :min_rt        => 4,
          },
        }
      end
    end
  end
end
