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
        @@weapon_stats_edged = {
          :arrow         => { # when swung, not when fired
            :category      => :edged,
            :base_name     => "arrow",
            :all_names     => ["sitka", "arrow"],
            :damage_types  => [slash: 33.3, crush: 0.0, puncture: 66.7, special: []],
            :damage_factor => [nil, 0.200, 0.100, 0.080, 0.100, 0.040],
            #                       /Cloth            / Leather       / Scale      / Chain       / Plate
            :avd_by_asg    => [nil, 20, 20, nil, nil, 18, 17, 16, 15, 10, 8, 6, 4, 5, 1, -3, -7, -5, -11, -17, -23],
            :base_rt       => 5,
            :min_rt        => 4,
          },
          :backsword     => {
            :category      => :edged,
            :base_name     => "backsword",
            :all_names     => ["backsword", "mortuary sword", "riding sword", "sidesword"],
            :damage_types  => [slash: 50.0, crush: 16.7, puncture: 33.3, special: []],
            :damage_factor => [nil, 0.310, 0.225, 0.240, 0.125, 0.150],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 38, 38, nil, nil, 38, 37, 36, 35, 34, 32, 30, 28, 38, 34, 30, 26, 34, 28, 22, 16],
            :base_rt       => 5,
            :min_rt        => 4,
          },
          :bastard_sword => {
            :category      => :edged,
            :base_name     => "bastard sword",
            :all_names     => ["bastard sword", "cresset sword", "espadon", "war sword"],
            :damage_types  => [slash: 66.7, crush: 33.3, puncture: 0.0, special: []],
            :damage_factor => [nil, 0.450, 0.325, 0.275, 0.250, 0.180],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 30, 30, nil, nil, 31, 30, 29, 28, 31, 29, 27, 25, 32, 28, 24, 20, 31, 25, 19, 13],
            :base_rt       => 6,
            :min_rt        => 4,
            :grippable?    => true,
          },
          :broadsword    => {
            :category      => :edged,
            :base_name     => "broadsword",
            :all_names     => ["broadsword", "carp's tongue", "carp's-tongue", "flyssa", "goliah", "katzbalger", "kurzsax", "machera", "palache", "schiavona", "seax", "spadroon", "spatha", "talon sword", "xiphos"],
            :damage_types  => [slash: 50.0, crush: 16.7, puncture: 33.3, special: []],
            :damage_factor => [nil, 0.450, 0.300, 0.250, 0.225, 0.200],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 36, 36, nil, nil, 36, 35, 34, 33, 36, 34, 32, 30, 37, 33, 29, 25, 36, 30, 24, 18],
            :base_rt       => 5,
            :min_rt        => 4,
          },
          :dagger        => {
            :category      => :edged,
            :base_name     => "dagger",
            :all_names     => ["alfange", "basilard", "bodice dagger", "bodkin", "boot dagger", "bracelet dagger", "butcher knife", "cinquedea", "crescent dagger", "dagger", "dirk", "fantail dagger", "forked dagger", "gimlet knife", "kaiken", "kidney dagger", "knife", "kozuka", "krizta", "kubikiri", "misericord", "parazonium", "pavade", "poignard", "pugio", "push dagger", "scramasax", "sgian achlais", "sgian dubh", "sidearm-of-Onar", "spike", "stiletto", "tanto", "trail knife", "trailknife", "zirah bouk"],
            :damage_types  => [slash: 33.3, crush: 0.0, puncture: 66.7, special: []],
            :damage_factor => [nil, 0.250, 0.200, 0.100, 0.125, 0.075],
            #                       /Cloth            / Leather       / Scale        / Chain       / Plate
            :avd_by_asg    => [nil, 25, 25, nil, nil, 23, 22, 21, 20, 15, 13, 11, 9, 10, 6, 2, -2, 0, -6, -12, -18],
            :base_rt       => 1,
            :min_rt        => 2,
          },
          :estoc         => {
            :category      => :edged,
            :base_name     => "estoc",
            :all_names     => ["estoc", "koncerz"],
            :damage_types  => [slash: 33.3, crush: 0.0, puncture: 66.7, special: []],
            :damage_factor => [nil, 0.425, 0.300, 0.200, 0.200, 0.150],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 36, 36, nil, nil, 38, 37, 36, 35, 35, 33, 31, 29, 40, 36, 32, 28, 30, 24, 18, 12],
            :base_rt       => 4,
            :min_rt        => 4,
          },
          :falchion      => {
            :category      => :edged,
            :base_name     => "falchion",
            :all_names     => ["falchion", "badelaire", "craquemarte", "falcata", "kiss-of-ivas", "khopesh", "kopis", "machete", "takouba", "warblade"],
            :damage_types  => [slash: 66.7, crush: 33.3, puncture: 0.0, special: []],
            :damage_factor => [nil, 0.450, 0.325, 0.250, 0.250, 0.175],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 35, 35, nil, nil, 37, 36, 35, 34, 38, 36, 34, 32, 39, 35, 31, 27, 39, 33, 27, 21],
            :base_rt       => 5,
            :min_rt        => 4,
          },
          :handaxe       => {
            :category      => :edged,
            :base_name     => "handaxe",
            :all_names     => ["handaxe", "balta", "boarding axe", "broad axe", "cleaver", "crescent axe", "double-bit axe", "field-axe", "francisca", "hatchet", "hunting axe", "hunting hatchet", "ice axe", "limb-cleaver", "logging axe", "meat cleaver", "miner's axe", "moon axe", "ono", "raiding axe", "sparte", "splitting axe", "throwing axe", "taper", "tomahawk", "toporok", "waraxe"],
            :damage_types  => [slash: 33.3, crush: 66.7, puncture: 0.0, special: []],
            :damage_factor => [nil, 0.420, 0.300, 0.270, 0.240, 0.210],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 30, 30, nil, nil, 32, 31, 30, 29, 38, 36, 34, 32, 41, 37, 33, 29, 41, 35, 29, 23],
            :base_rt       => 5,
            :min_rt        => 4,
          },
          :katana        => {
            :category         => :edged,
            :base_name        => "katana",
            :all_names        => ["katana"],
            :damage_types     => [slash: 100.0, crush: 0.0, puncture: 0.0, special: []],
            :damage_factor    => [nil, 0.450, 0.325, 0.275, 0.225, 0.175],
            #                       /Cloth               / Leather       / Scale         / Chain         / Plate
            :avd_by_asg       => [nil, 38, 38, nil, nil, 36, 35, 34, 33, 36, 34, 32, 30, 37, 33, 29, 25, 35, 29, 23, 17],
            :base_rt          => 5,
            :min_rt           => 4,
            :weighting_type   => :critical,
            :weighting_amount => 10,
            :grippable?       => true,
          },
          :longsword     => {
            :category      => :edged,
            :base_name     => "longsword",
            :all_names     => ["longsword", "arming sword", "kaskara", "langsax", "langseax", "mekya t'rhet", "sheering sword", "tachi"],
            :damage_types  => [slash: 50.0, crush: 16.7, puncture: 33.3, special: []],
            :damage_factor => [nil, 0.425, 0.275, 0.225, 0.200, 0.175],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 41, 41, nil, nil, 42, 41, 40, 39, 43, 41, 39, 37, 37, 33, 29, 25, 35, 29, 23, 17],
            :base_rt       => 4,
            :min_rt        => 4,
          },
          :main_gauche   => {
            :category      => :edged,
            :base_name     => "main gauche",
            :all_names     => ["parrying dagger", "main gauche", "shield-sword", "sword-breaker"],
            :damage_types  => [slash: 33.3, crush: 0.0, puncture: 66.7, special: []],
            :damage_factor => [nil, 0.275, 0.210, 0.110, 0.125, 0.075],
            #                       /Cloth            / Leather       / Scale         / Chain        / Plate
            :avd_by_asg    => [nil, 27, 27, nil, nil, 25, 24, 23, 22, 20, 18, 16, 14, 20, 16, 12, 8, 20, 14, 8, 2],
            :base_rt       => 2,
            :min_rt        => 3,
          },
          :rapier        => {
            :category      => :edged,
            :base_name     => "rapier",
            :all_names     => ["bilbo", "colichemarde", "epee", "fleuret", "foil", "rapier", "schlager", "tizona", "tock", "tocke", "tuck", "verdun"],
            :damage_types  => [slash: 33.3, crush: 0.0, puncture: 66.7, special: []],
            :damage_factor => [nil, 0.325, 0.225, 0.125, 0.125, 0.075],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 45, 45, nil, nil, 40, 39, 38, 37, 30, 28, 26, 24, 35, 31, 27, 23, 15, 9, 3, -3],
            :base_rt       => 2,
            :min_rt        => 3,
          },
          :scimitar      => {
            :category      => :edged,
            :base_name     => "scimitar",
            :all_names     => ["scimitar", "charl's-tail", "cutlass", "disackn", "kilij", "palache", "sabre", "sapara", "shamshir", "yataghan"],
            :damage_types  => [slash: 50.0, crush: 16.7, puncture: 33.3, special: []],
            :damage_factor => [nil, 0.375, 0.260, 0.210, 0.200, 0.165],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 30, 30, nil, nil, 31, 30, 29, 28, 30, 28, 26, 24, 30, 26, 22, 18, 30, 24, 18, 12],
            :base_rt       => 4,
            :min_rt        => 4,
          },
          :short_sword   => {
            :category      => :edged,
            :base_name     => "short sword",
            :all_names     => ["acinaces", "antler sword", "backslasher", "braquemar", "baselard", "chereb", "coustille", "gladius", "gladius graecus", "kris", "kukri", "Niima's-embrace", "sica", "wakizashi"],
            :damage_types  => [slash: 33.3, crush: 33.3, puncture: 33.3, special: []],
            :damage_factor => [nil, 0.350, 0.240, 0.200, 0.150, 0.125],
            #                       /Cloth             / Leather      / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 40, 40, nil, nil, 36, 35, 34, 33, 30, 28, 26, 24, 25, 21, 17, 13, 25, 19, 13, 7],
            :base_rt       => 3,
            :min_rt        => 3,
          },
          :whip_blade    => {
            :category      => :edged,
            :base_name     => "whip-blade",
            :all_names     => ["whip-blade", "whipblade"],
            :damage_types  => [slash: 100.0, crush: 0.0, puncture: 0.0, special: []],
            :damage_factor => [nil, 0.333, 0.225, 0.125, 0.115, 0.065],
            #                       /Cloth            / Leather       / Scale         / Chain         / Plate
            :avd_by_asg    => [nil, 45, 45, nil, nil, 40, 39, 38, 37, 30, 28, 26, 24, 35, 31, 27, 23, 15, 9, 3, -3],
            :base_rt       => 2,
            :min_rt        => 3,
          },
        }
      end
    end
  end
end
