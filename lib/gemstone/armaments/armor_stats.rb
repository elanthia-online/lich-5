module Lich
  module Gemstone
    module Armaments
      # ArmorStats module contains metadata definitions for individual armor types,
      # ...
      module ArmorStats
        # Hinderances Array:
        # [0] - nil               [1] - Minor Spiritual         [2] - Major Spiritual        [3] - Cleric Base
        # [4] - Minor Elemental   [5] - Major Elemental         [6] - Ranger Base            [7] - Sorceror Base
        # [8] - Old Empath Base   [9] - Wizard Base             [10] - Bard Base             [11] - Empath Base
        # [12] - Minor Mental     [13] - Major Mental           [14] - Savant Base           [15] - nil
        # [16] - Paladin Base     [17] - Arcane Spells
        @@armor_stats = [
          "asg_1" => {
            :category        => :cloth,
            :base_name       => "normal clothing",
            :all_names       => ["normal clothing", "clothing", "cloth armor"],
            :armor_group     => 1,
            :armor_sub_group => 1,
            :base_weight     => 0,
            :min_rt          => 0,
            :action_penalty  => 0,
            :normal_cva      => 25,
            :magical_cva     => 20,
            #                     0    1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17
            :hinderances     => [nil, 0, 0, 0, 0, 0, 0, 0, nil, 0, 0, 0, 0, 0, nil, nil, 0, nil],
          },
          "asg_2" => {
            :category        => :cloth,
            :base_name       => "robes",
            :all_names       => ["robes", "robe", "cloth armor"],
            :armor_group     => 1,
            :armor_sub_group => 2,
            :base_weight     => 8,
            :min_rt          => 0,
            :action_penalty  => 0,
            :normal_cva      => 25,
            :magical_cva     => 20,
            #                     0    1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17
            :hinderances     => [nil, 0, 0, 0, 0, 0, 0, 0, nil, 0, 0, 0, 0, 0, nil, nil, 0, nil],
          },
        ]

        # Returns the critical hit divisor based on armor category.
        #
        # @param category [Symbol] The armor category (:cloth, :leather, etc.).
        # @return [Integer, nil] The crit divisor value, or nil if category is unknown.
        def self.find_crit_divisor_by_category(category)
          { cloth: 5, leather: 6, scale: 7, chain: 9, plate: 11 }[category]
        end

        # Finds the weapon's stats hash by one of its names.
        #
        # @param name [String] The name or alias of the weapon.
        # @return [Hash, nil] The stats hash of the matching weapon, or nil if not found.
        def self.find_type_by_name(name)
          _, armor_info = @@armor_stats.find { |_, stats| stats[:all_names].include?(name) }
          return armor_info
        end

        # Finds the weapon's category by one of its alternative names.
        #
        # @param name [String] The name or alias of the weapon.
        # @return [Symbol, nil] The weapon's category if found, otherwise nil.
        def self.find_category_by_name(name)
          _, armor_info = @@armor_stats.find { |_, stats| stats[:all_names].include?(name) }
          return armor_info ? armor_info[:category] : nil
        end
      end
    end
  end
end
