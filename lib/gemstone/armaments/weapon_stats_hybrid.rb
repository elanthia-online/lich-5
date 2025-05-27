module Lich
  module Gemstone
    module Armaments
      module WeaponStats
        @@weapon_stats_hybrid = [
          # Hybrid Weapons
          "katar"  => {
            :category      => :HYBRID,
            :hybrid_skills => [:OHE, :BRAWL],
            :base_name     => "katar",
            :all_names     => ["gauntlet-sword", "kunai", "manople", "paiscush", "pata", "slasher", "tvekre"],
            :damage_types  => [33.3, 0.0, 66.7],
            :damage_factor => [nil, 0.325, 0.250, 0.225, 0.200, 0.175],
            #                       /Cloth             / Leather       / Scale      / Chain       / Plate
            :avd_by_asg    => [nil, 30, nil, nil, nil, 32, 31, 30, 29, 40, 38, 36, 34, 45, 41, 37, 33, 40, 34, 28, 22],
            :base_rt       => 3,
            :min_rt        => 3,
          },
          "katana_ohe" => {
            :category      => :HYBRID,
            :hybrid_skills => [:THW, :OHE],
            :base_name     => "katana",
            :all_names     => ["katana", "tachi", "nodachi", "daito"],
            :damage_types  => [33.3, 0.0, 66.7],
            :damage_factor => [nil, 0.325, 0.250, 0.225, 0.200, 0.175],
            #                       /Cloth             / Leather       / Scale      / Chain       / Plate
            :avd_by_asg    => [nil, 30, nil, nil, nil, 32, 31, 30, 29, 40, 38, 36, 34, 45, 41, 37, 33, 40, 34, 28, 22],
            :base_rt       => 3,
            :min_rt        => 3,
          }, # fix data above
        ]
      end
    end
  end
end
