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
        @@weapon_stats_brawling = [
          :closed_fist    => {
            :category      => :brawling,
            :base_name     => "closed fist",
            :all_names     => ["closed fist"],
            :damage_types  => [slash: 0.0, crush: 100.0, puncture: 0.0, special: [:none]],
            :damage_factor => [nil, 0.100, 0.075, 0.040, 0.036, 0.032],
            #                       /Cloth            / Leather       / Scale      / Chain       / Plate
            :avd_by_asg    => [nil, 25, 25, nil, nil, 20, 19, 18, 17, 10, 8, 6, 4, 5, 1, -3, -7, -5, -11, -17, -23],
            :base_rt       => 1,
            :min_rt        => 2,
          },
          :blackjack      => {
            :category      => :brawling,
            :base_name     => "blackjack",
            :all_names     => ["blackjack", "bludgeon", "sap"],
            :damage_types  => [slash: 0.0, crush: 100.0, puncture: 0.0, special: [:none]],
            :damage_factor => [nil, 0.250, 0.140, 0.090, 0.110, 0.075],
            #                       /Cloth            / Leather       / Scale         / Chain       / Plate
            :avd_by_asg    => [nil, 40, 40, nil, nil, 35, 34, 33, 32, 25, 23, 21, 19, 15, 11, 7, 3, 0, -6, -12, -18],
            :base_rt       => 1,
            :min_rt        => 2,
          },
          :cestus         => {
            :category      => :brawling,
            :base_name     => "cestus",
            :all_names     => ["cestus"],
            :damage_types  => [slash: 0.0, crush: 100.0, puncture: 0.0, special: [:none]],
            :damage_factor => [nil, 0.250, 0.175, 0.150, 0.075, 0.035],
            #                       /Cloth            / Leather       / Scale         / Chain       / Plate
            :avd_by_asg    => [nil, 40, 40, nil, nil, 30, 29, 28, 27, 20, 18, 16, 14, 10, 6, 2, -2, -25, -31, -37, -43],
            :base_rt       => 1,
            :min_rt        => 2,
          },
          :fist_scythe    => {
            :category      => :brawling,
            :base_name     => "fist-scythe",
            :all_names     => ["fist-scythe", "hand-hook", "hook", "hook-claw", "kama", "sickle"],
            :damage_types  => [slash: 66.7, crush: 16.7, puncture: 16.6, special: [:none]],
            :damage_factor => [nil, 0.350, 0.225, 0.200, 0.175, 0.125],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 45, 45, nil, nil, 40, 39, 38, 37, 30, 28, 26, 24, 37, 33, 29, 25, 20, 14, 8, 2],
            :base_rt       => 3,
            :min_rt        => 3,
          },
          :hook_knife     => {
            :category      => :brawling,
            :base_name     => "hook-knife",
            :all_names     => ["hook-knife", "pit-knife", "sabiet"],
            :damage_types  => [slash: nil, crush: 0.0, puncture: nil, special: [:none]], # Missing Data on Wiki
            :damage_factor => [nil, 0.250, 0.175, 0.125, 0.070, 0.035],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 40, 40, nil, nil, 30, 29, 28, 27, 18, 16, 13, 12, 10, 6, 2, -2, -15, -21, -27, -33],
            :base_rt       => 1,
            :min_rt        => 2,
          },
          :jackblade      => {
            :category      => :brawling,
            :base_name     => "jackblade",
            :all_names     => ["jackblade", "slash-jack"],
            :damage_types  => [slash: nil, crush: nil, puncture: 0.0, special: [:none]], # Missing Data on Wiki
            :damage_factor => [nil, 0.250, 0.175, 0.150, 0.150, 0.110],
            #                       /Cloth            / Leather       / Scale         / Chain        / Plate
            :avd_by_asg    => [nil, 45, 45, nil, nil, 35, 34, 33, 32, 25, 23, 21, 19, 20, 16, 12, 8, 10, 4, -2, -8],
            :base_rt       => 2,
            :min_rt        => 3,
          },
          :paingrip       => {
            :category      => :brawling,
            :base_name     => "paingrip",
            :all_names     => ["paingrip", "grab-stabber"],
            :damage_types  => [slash: nil, crush: nil, puncture: nil, special: [:none]], # Missing Data on Wiki
            :damage_factor => [nil, 0.225, 0.200, 0.125, 0.075, 0.030],
            #                       /Cloth            / Leather       / Scale        / Chain       / Plate
            :avd_by_asg    => [nil, 40, 40, nil, nil, 20, 19, 18, 17, 15, 13, 11, 9, 15, 11, 7, 3, -25, -31, -37, -43],
            :base_rt       => 1,
            :min_rt        => 2,
          },
          :sai            => {
            :category      => :brawling,
            :base_name     => "sai",
            :all_names     => ["sai", "jitte"],
            :damage_types  => [slash: 0.0, crush: 0.0, puncture: 100.0, special: [:none]],
            :damage_factor => [nil, 0.250, 0.200, 0.110, 0.150, 0.040],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 30, 30, nil, nil, 31, 30, 29, 28, 25, 23, 21, 19, 33, 29, 25, 21, 6, 0, -6, -12],
            :base_rt       => 2,
            :min_rt        => 3,
          },
          :knuckle_blade  => {
            :category      => :brawling,
            :base_name     => "knuckle-blade",
            :all_names     => ["knuckle-blade", "slash-fist"],
            :damage_types  => [slash: 66.7, crush: 33.3, puncture: 0.0, special: [:none]],
            :damage_factor => [nil, 0.250, 0.150, 0.100, 0.075, 0.075],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 45, 45, nil, nil, 40, 39, 38, 37, 25, 23, 21, 19, 25, 21, 17, 13, 0, -6, -12, -18],
            :base_rt       => 1,
            :min_rt        => 2,
          },
          :knuckle_duster => {
            :category      => :brawling,
            :base_name     => "knuckle-duster",
            :all_names     => ["knuckle-duster", "knuckle-guard", "knuckles"],
            :damage_types  => [slash: 0.0, crush: 100.0, puncture: 0.0, special: [:none]],
            :damage_factor => [nil, 0.250, 0.175, 0.125, 0.100, 0.040],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 35, 35, nil, nil, 32, 31, 30, 29, 25, 23, 21, 19, 18, 14, 10, 6, 0, -6, -12, -18],
            :base_rt       => 1,
            :min_rt        => 2,
          },
          :razorpaw       => {
            :category      => :brawling,
            :base_name     => "razorpaw",
            :all_names     => ["razorpaw", "slap-slasher"],
            :damage_types  => [slash: 100.0, crush: 0.0, puncture: 0.0, special: [:none]],
            :damage_factor => [nil, 0.275, 0.200, 0.125, 0.050, 0.030],
            #                       /Cloth            / Leather       / Scale      / Chain         / Plate
            :avd_by_asg    => [nil, 35, 35, nil, nil, 20, 19, 18, 17, 10, 8, 6, 4, 0, -4, -8, -12, -25, -31, -37, -43],
            :base_rt       => 1,
            :min_rt        => 2,
          },
          :tiger_claw     => {
            :category      => :brawling,
            :base_name     => "tiger-claw",
            :all_names     => ["tiger-claw", "thrak-bite", "barbed claw"],
            :damage_types  => [slash: nil, crush: nil, puncture: 0.0, special: [:none]], # Missing Data on Wiki
            :damage_factor => [nil, 0.275, 0.200, 0.150, 0.100, 0.035],
            #                       /Cloth            / Leather       / Scale        / Chain       / Plate
            :avd_by_asg    => [nil, 40, 40, nil, nil, 25, 24, 23, 22, 15, 13, 11, 9, 5, 1, -3, -7, -25, -31, -37, -43],
            :base_rt       => 1,
            :min_rt        => 2,
          },
          :troll_claw     => {
            :category      => :brawling,
            :base_name     => "troll-claw",
            :all_names     => ["troll-claw", "bladed claw", "kumade", "wight-claw"],
            :damage_types  => [slash: nil, crush: nil, puncture: 0.0, special: [:none]], # Missing Data on Wiki
            :damage_factor => [nil, 0.325, 0.175, 0.140, 0.120, 0.090],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 46, 46, nil, nil, 35, 34, 33, 32, 25, 23, 21, 19, 25, 21, 17, 13, 15, 9, 3, -3],
            :base_rt       => 2,
            :min_rt        => 3,
          },
          :yierka_spur    => {
            :category      => :brawling,
            :base_name     => "yierka-spur",
            :all_names     => ["yierka-spur", "spike-fist"],
            :damage_types  => [slash: nil, crush: nil, puncture: nil, special: [:none]], # Missing Data on Wiki
            :damage_factor => [nil, 0.250, 0.150, 0.125, 0.125, 0.075],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 40, 40, nil, nil, 35, 34, 33, 32, 25, 23, 21, 19, 30, 26, 22, 18, 0, -6, -12, -18],
            :base_rt       => 1,
            :min_rt        => 2,
          },
        ]
      end
    end
  end
end
