module Lich
  module Gemstone
    module Armaments
      module WeaponStats
# Static array of weapon stats indexed by weapon identifiers. Each weapon
# entry contains metadata such as category, base name, alternative names,
# damage types, damage factors, armor avoidance by armor size group (ASG),
# base roundtime (RT), and minimum RT.

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
        @@weapon_stats_unarmed = {
          :cestus         => {
            :category                => :unarmed,
            :base_name               => "cestus",
            :all_names               => ["cestus"],
            :damage_factor_modifier  => 0.25,
            :ucs_multiplier_modifier => -5,
            :both_hands?             => true, # may hold two for additional bonuses
            :both_hands_modifier     => 2, # multiplies the modifiers by 2
            :held_or_worn            => :held,
          },
          :footwraps      => {
            :category                => :unarmed,
            :base_name               => "footwraps",
            :all_names               => ["footwraps", "boots"], # additional names could exist, there is no list on the wiki of allowable nouns
            :damage_factor_modifier  => 0.0,
            :ucs_multiplier_modifier => 0,
            :both_hands?             => nil, # does not apply
            :both_hands_modifier     => nil, # does not apply
            :held_or_worn            => :worn,
          },
          :handwraps      => {
            :category                => :unarmed,
            :base_name               => "handwraps",
            :all_names               => ["handwraps", "gloves", "gauntlet"], # additional names could exist, there is no list on the wiki of allowable nouns
            :damage_factor_modifier  => 0.0,
            :ucs_multiplier_modifier => 0,
            :both_hands?             => nil, # does not apply
            :both_hands_modifier     => nil, # does not apply
            :held_or_worn            => :worn,
          },
          :knuckle_blade  => {
            :category                => :unarmed,
            :base_name               => "knuckle-blade",
            :all_names               => ["knuckle-blade", "slash-fist"],
            :damage_factor_modifier  => 0.50,
            :ucs_multiplier_modifier => -10,
            :both_hands?             => true, # may hold two for additional bonuses
            :both_hands_modifier     => 2, # multiplies the modifiers by 2
            :held_or_worn            => :held,
          },
          :knuckle_duster => {
            :category                => :unarmed,
            :base_name               => "knuckle-duster",
            :all_names               => ["knuckle-duster", "knuckle-guard", "knuckles"],
            :damage_factor_modifier  => 0.50,
            :ucs_multiplier_modifier => -10,
            :both_hands?             => true, # may hold two for additional bonuses
            :both_hands_modifier     => 2, # multiplies the modifiers by 2
            :held_or_worn            => :held,
          },
          :paingrip       => {
            :category                => :unarmed,
            :base_name               => "paingrip",
            :all_names               => ["paingrip", "grab-stabber"],
            :damage_factor_modifier  => 0.25,
            :ucs_multiplier_modifier => -5,
            :both_hands?             => true, # may hold two for additional bonuses
            :both_hands_modifier     => 2, # multiplies the modifiers by 2
            :held_or_worn            => :held,
          },
          :razorpaw       => {
            :category                => :unarmed,
            :base_name               => "razorpaw",
            :all_names               => ["razorpaw", "slap-slasher"],
            :damage_factor_modifier  => 0.25,
            :ucs_multiplier_modifier => -5,
            :both_hands?             => true, # may hold two for additional bonuses
            :both_hands_modifier     => 2, # multiplies the modifiers by 2
            :held_or_worn            => :held,
          },
          :tiger_claw     => {
            :category                => :unarmed,
            :base_name               => "tiger-claw",
            :all_names               => ["tiger-claw", "thrak-bite", "barbed claw"],
            :damage_factor_modifier  => 0.75,
            :ucs_multiplier_modifier => -15,
            :both_hands?             => true, # may hold two for additional bonuses
            :both_hands_modifier     => 2, # multiplies the modifiers by 2
            :held_or_worn            => :held,
          },
          :yierka_spur    => {
            :category                => :unarmed,
            :base_name               => "yierka-spur",
            :all_names               => ["yierka-spur", "spike-fist"],
            :damage_factor_modifier  => 0.75,
            :ucs_multiplier_modifier => -15,
            :both_hands?             => true, # may hold two for additional bonuses
            :both_hands_modifier     => 2, # multiplies the modifiers by 2
            :held_or_worn            => :held,
          },
        }
      end
    end
  end
end
