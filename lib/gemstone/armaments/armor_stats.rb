module Lich
  module Gemstone
    module Armaments
      # ArmorStats module provides utility methods for handling armor data,
      # including retrieving armor information based on alternative names and
      # categories.
      module ArmorStats
        # Static array of armor stats indexed by armor identifiers. Each armor
        # entry contains metadata such as category, alternative names, size and
        # evade modifiers, and base weight.
        #
        # hindrances/Training Requirements Array:
        # [0] - nil (Act Pen)     [1] - Minor Spiritual         [2] - Major Spiritual        [3] - Cleric Base
        # [4] - Minor Elemental   [5] - Major Elemental         [6] - Ranger Base            [7] - Sorcerer Base
        # [8] - Old Empath Base   [9] - Wizard Base             [10] - Bard Base             [11] - Empath Base
        # [12] - Minor Mental     [13] - Major Mental           [14] - Savant Base           [15] - nil
        # [16] - Paladin Base     [17] - Arcane Spells          [18] - nil                   [19] - Lost Arts
        @@armor_stats = {
          :ag_1 => {
            :asg_1 => { # Cloth
              :type            => :cloth,
              :base_name       => :normal_clothing,
              :all_names       => ["normal clothing", "clothing", "clothes", "garb", "garments", "outfit", "attire", "ensemble"],
              :armor_group     => 1,
              :armor_sub_group => 1,
              :base_weight     => 0,
              :min_rt          => 0,
              :action_penalty  => 0,
              :normal_cva      => 25,
              :magical_cva     => 20,
              #                    AP 1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :hindrances      => [0, 0, 0, 0, 0, 0, 0, 0, nil, 0, 0, 0, 0, 0, nil, nil, 0, nil, nil, nil],
              :hindrance_max   => 0,
              #                    AP 1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :training_reqs   => [0, 0, 0, 0, 0, 0, 0, 0, nil, 0, 0, 0, 0, 0, nil, nil, 0, nil, nil, nil],
            },
            :asg_2 => {
              :type            => :cloth,
              :base_name       => :robes,
              :all_names       => ["robes", "robe", "vestments", "tunic"],
              :armor_group     => 1,
              :armor_sub_group => 2,
              :base_weight     => 8,
              :min_rt          => 0,
              :action_penalty  => 0,
              :normal_cva      => 25,
              :magical_cva     => 20,
              #                    AP 1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :hindrances      => [0, 0, 0, 0, 0, 0, 0, 0, nil, 0, 0, 0, 0, 0, nil, nil, 0, nil, nil, nil],
              :hindrance_max   => 0,
              #                    AP 1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :training_reqs   => [0, 0, 0, 0, 0, 0, 0, 0, nil, 0, 0, 0, 0, 0, nil, nil, 0, nil, nil, nil],
            },
            :asg_3 => nil, # not used
            :asg_4 => nil, # not used
          },
          :ag_2 => { # Leather
            :asg_5 => {
              :type            => :leather,
              :base_name       => :light_leather,
              :all_names       => ["light leather", "light leathers", "buffcoat", "casting leather", "casting leathers", "jack", "leather cyclas", "leather jerkin", "leather shirt", "leather tunic", "leather vest", "leather", "leathers", "hunts"],
              :armor_group     => 2,
              :armor_sub_group => 5,
              :base_weight     => 10,
              :min_rt          => 0,
              :action_penalty  => 0,
              :normal_cva      => 20,
              :magical_cva     => 15,
              #                    AP 1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :hindrances      => [0, 0, 0, 0, 0, 0, 0, 0, nil, 0, 0, 0, 0, 0, nil, nil, 0, nil, nil, nil],
              :hindrance_max   => 0,
              #                    AP 1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :training_reqs   => [0, 0, 0, 0, 0, 0, 0, 0, nil, 0, 0, 0, 0, 0, nil, nil, 0, nil, nil, nil],
            },
            :asg_6 => {
              :type            => :leather,
              :base_name       => :full_leather,
              :all_names       => ["full leather", "full leathers", "arming doublet", "buffcoat", "casting leather", "casting leathers", "leather shirt", "leather pourpoint", "leather", "leathers", "hunts"],
              :armor_group     => 2,
              :armor_sub_group => 6,
              :base_weight     => 13,
              :min_rt          => 1,
              :action_penalty  => -1,
              :normal_cva      => 19,
              :magical_cva     => 14,
              #                    AP  1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :hindrances      => [-1, 0, 0, 0, 0, 0, 0, 0, nil, 0, 0, 0, 0, 0, nil, nil, 0, nil, nil, nil],
              :hindrance_max   => 0,
              #                    AP 1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :training_reqs   => [2, 0, 0, 0, 0, 0, 0, 0, nil, 0, 0, 0, 0, 0, nil, nil, 0, nil, nil, nil],
            },
            :asg_7 => {
              :type            => :leather,
              :base_name       => :reinforced_leather,
              :all_names       => ["reinforced leather", "reinforced leathers", "aketon", "arming coat", "arming doublet", "gambeson", "quilted leather", "leather", "leathers", "hunts"],
              :armor_group     => 2,
              :armor_sub_group => 7,
              :base_weight     => 15,
              :min_rt          => 2,
              :action_penalty  => -5,
              :normal_cva      => 18,
              :magical_cva     => 13,
              #                    AP  1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :hindrances      => [-5, 0, 0, 0, 0, 2, 0, 1, nil, 2, 0, 0, 0, 2, nil, nil, 0, nil, nil, nil],
              :hindrance_max   => 4,
              #                    AP 1  2  3  4  5  6  7  8    9  10 11 12 13 14 15   16 17   18   19
              :training_reqs   => [6, 0, 0, 0, 0, 6, 0, 2, nil, 6, 0, 0, 0, 6, 6, nil, 0, nil, nil, nil],
            },
            :asg_8 => {
              :type            => :leather,
              :base_name       => :double_leather,
              :all_names       => ["double leather", "double leathers", "aketon", "arming coat", "gambeson", "bodysuit", "leather", "leathers", "hunts"],
              :armor_group     => 2,
              :armor_sub_group => 8,
              :base_weight     => 16,
              :min_rt          => 2,
              :action_penalty  => -6,
              :normal_cva      => 17,
              :magical_cva     => 12,
              #                    AP  1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :hindrances      => [-6, 0, 0, 0, 0, 4, 0, 2, nil, 4, 2, 0, 2, 4, nil, nil, 0, nil, nil, nil],
              :hindrance_max   => 6,
              #                    AP 1  2  3  4  5   6  7  8    9   10 11 12 13  14  15   16 17   18   19
              :training_reqs   => [6, 0, 0, 0, 0, 15, 0, 6, nil, 15, 6, 0, 6, 15, 15, nil, 0, nil, nil, nil],
            },
          },
          :ag_3 => { # Scale
            :asg_9  => {
              :type            => :scale,
              :base_name       => :leather_breastplate,
              :all_names       => ["leather breastplate", "breastplate", "brigandine shirt", "corslet/corselet", "cuirass", "jack", "jerkin", "lamellar shirt", "scale", "scalemail", "tunic", "armor"],
              :armor_group     => 3,
              :armor_sub_group => 9,
              :base_weight     => 16,
              :min_rt          => 3,
              :action_penalty  => -7,
              :normal_cva      => 11,
              :magical_cva     => 5,
              #                    AP  1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :hindrances      => [-7, 3, 4, 4, 4, 6, 3, 5, nil, 6, 3, 4, 4, 6, nil, nil, 2, nil, nil, nil],
              :hindrance_max   => 16,
              #                    AP  1   2   3   4   5   6   7   8    9   10  11  12  13  14  15   16 17   18   19
              :training_reqs   => [10, 10, 15, 15, 15, 27, 10, 20, nil, 27, 10, 15, 15, 27, 27, nil, 6, nil, nil, nil],
            },
            :asg_10 => {
              :type            => :scale,
              :base_name       => :cuirboulli_leather,
              :all_names       => ["cuirboulli", "cuirboulli leather", "cuirboulli leathers", "brigandine shirt", "cuirass", "jerkin", "lamellar corslet/corselet", "lamellar shirt", "leather corslet/corselet", "scale", "scalemail", "tunic", "armor"],
              :armor_group     => 3,
              :armor_sub_group => 10,
              :base_weight     => 17,
              :min_rt          => 4,
              :action_penalty  => -8,
              :normal_cva      => 10,
              :magical_cva     => 4,
              #                    AP   1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :hindrances      => [-8, 4, 5, 5, 5, 7, 4, 6, nil, 7, 3, 5, 5, 7, nil, nil, 3, nil, nil, nil],
              :hindrance_max   => 20,
              #                    AP  1   2   3   4   5   6   7   8    9   10  11  12  13  14  15   16  17   18   19
              :training_reqs   => [15, 15, 20, 20, 20, 35, 15, 27, nil, 35, 10, 20, 20, 35, 35, nil, 10, nil, nil, nil],
            },
            :asg_11 => {
              :type            => :scale,
              :base_name       => :studded_leather,
              :all_names       => ["studded leather", "studded leathers", "splint leather", "splinted leather", "lamellar leather", "armor"],
              :armor_group     => 3,
              :armor_sub_group => 11,
              :base_weight     => 20,
              :min_rt          => 5,
              :action_penalty  => -10,
              :normal_cva      => 9,
              :magical_cva     => 3,
              #                    AP   1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :hindrances      => [-10, 5, 6, 6, 6, 9, 5, 8, nil, 9, 3, 6, 6, 9, nil, nil, 4, nil, nil, nil],
              :hindrance_max   => 24,
              #                    AP  1   2   3   4   5   6   7   8    9   10  11  12  13  14  15   16  17   18   19
              :training_reqs   => [20, 20, 27, 27, 27, 70, 20, 50, nil, 70, 10, 27, 27, 70, 70, nil, 15, nil, nil, nil],
            },
            :asg_12 => {
              :type            => :scale,
              :base_name       => :brigandine_armor,
              :all_names       => ["brigandine", "brigandine armor", "brigandine leather", "banded armor", "coat-of-plates", "jack-of-plates", "kuyak", "laminar armor", "lamellar armor", "scalemail", "splint armor", "splinted armor", "splint mail", "splinted mail", "armor"],
              :armor_group     => 3,
              :armor_sub_group => 12,
              :base_weight     => 25,
              :min_rt          => 6,
              :action_penalty  => -12,
              :normal_cva      => 8,
              :magical_cva     => 2,
              #                    AP   1  2  3  4  5   6  7   8    9   10 11 12 13  14   15   16 17   18   19
              :hindrances      => [-12, 6, 7, 7, 7, 12, 6, 11, nil, 12, 7, 7, 7, 12, nil, nil, 5, nil, nil, nil],
              :hindrance_max   => 28,
              #                    AP  1   2   3   4   5    6   7    8    9    10  11  12  13   14   15   16  17   18   19
              :training_reqs   => [27, 27, 35, 35, 35, 130, 27, 110, nil, 130, 35, 35, 35, 130, 130, nil, 20, nil, nil, nil],
            },
          },
          :ag_4 => { # Chain
            :asg_13 => {
              :type            => :chain,
              :base_name       => :chain_mail,
              :all_names       => ["chain", "chainmail", "chain armor", "mail", "ringmail", "byrnie", "chain corslet/corselet", "chain shirt", "chain tunic"],
              :armor_group     => 4,
              :armor_sub_group => 13,
              :base_weight     => 25,
              :min_rt          => 7,
              :action_penalty  => -13,
              :normal_cva      => 1,
              :magical_cva     => -6,
              #                    AP   1  2  3  4  5   6  7   8    9   10 11 12 13  14   15   16 17   18   19
              :hindrances      => [-13, 7, 8, 8, 8, 16, 7, 16, nil, 16, 8, 8, 6, 16, nil, nil, 6, nil, nil, nil],
              :hindrance_max   => 40,
              #                    AP  1   2   3   4   5    6   7    8    9    10  11  12   13   14   15   16  17   18   19
              :training_reqs   => [35, 35, 50, 50, 50, 210, 35, 210, nil, 210, 50, 50, 50, 210, 210, nil, 27, nil, nil, nil],
            },
            :asg_14 => {
              :type            => :chain,
              :base_name       => :double_chain,
              :all_names       => ["chain", "chainmail", "chain armor", "mail", "ringmail", "double chain", "double chainmail", "chain corslet/corselet", "chain shirt", "chain tunic", "haubergeon", "jazerant"],
              :armor_group     => 4,
              :armor_sub_group => 14,
              :base_weight     => 25,
              :min_rt          => 8,
              :action_penalty  => -14,
              :normal_cva      => 0,
              :magical_cva     => -7,
              #                    AP   1  2  3  4  5   6  7   8    9   10 11 12 13  14   15   16 17   18   19
              :hindrances      => [-14, 8, 9, 9, 9, 20, 8, 18, nil, 20, 8, 9, 9, 20, nil, nil, 7, nil, nil, nil],
              :hindrance_max   => 45,
              #                    AP  1   2   3   4   5    6   7    8    9    10  11  12  13   14   15   16  17   18   19
              :training_reqs   => [50, 50, 70, 70, 70, 290, 50, 250, nil, 290, 50, 70, 70, 290, 290, nil, 35, nil, nil, nil],
            },
            :asg_15 => {
              :type            => :chain,
              :base_name       => :augmented_chain,
              :all_names       => ["chain", "chainmail", "chain armor", "mail", "ringmail", "augmented chain", "augmented chainmail", "haubergeon", "jazerant"],
              :armor_group     => 4,
              :armor_sub_group => 15,
              :base_weight     => 26,
              :min_rt          => 8,
              :action_penalty  => -16,
              :normal_cva      => -1,
              :magical_cva     => -8,
              #                    AP   1  2   3   4   5   6  7   8    9   10 11  12  13  14   15   16 17   18   19
              :hindrances      => [-16, 9, 11, 11, 10, 25, 9, 22, nil, 25, 8, 11, 10, 25, nil, nil, 8, nil, nil, nil],
              :hindrance_max   => 55,
              #                    AP  1   2    3    4   5    6   7    8    9    10  11   12  13   14   15   16  17   18   19
              :training_reqs   => [50, 70, 110, 110, 90, 390, 70, 330, nil, 390, 50, 110, 90, 390, 390, nil, 50, nil, nil, nil],
            },
            :asg_16 => {
              :type            => :chain,
              :base_name       => :chain_hauberk,
              :all_names       => ["chain", "chainmail", "chain armor", "mail", "ringmail", "chain hauberk", "body armor", "hauberk", "jazerant hauberk"],
              :armor_group     => 4,
              :armor_sub_group => 16,
              :base_weight     => 27,
              :min_rt          => 9,
              :action_penalty  => -18,
              :normal_cva      => -2,
              :magical_cva     => -9,
              #                    AP   1   2   3   4   5   6   7   8    9   10  11  12  13  14   15   16 17   18   19
              :hindrances      => [-18, 11, 14, 14, 12, 30, 11, 26, nil, 30, 15, 14, 15, 30, nil, nil, 9, nil, nil, nil],
              :hindrance_max   => 60,
              #                    AP  1    2    3    4    5    6    7    8    9    10   11   12   13   14   15   16  17   18   19
              :training_reqs   => [70, 110, 170, 170, 130, 490, 110, 410, nil, 490, 190, 190, 190, 490, 490, nil, 70, nil, nil, nil],
            },
          },
          :ag_5 => { # Plate
            :asg_17 => {
              :type            => :plate,
              :base_name       => :metal_breastplate,
              :all_names       => ["plate armor", "plate-and-mail", "metal breastplate", "breastplate", "cuirass", "disc armor", "mirror armor", "plate corslet", "plate corselet"],
              :armor_group     => 5,
              :armor_sub_group => 17,
              :base_weight     => 23,
              :min_rt          => 9,
              :action_penalty  => -20,
              :normal_cva      => -10,
              :magical_cva     => -18,
              #                    AP   1   2   3   4   5   6   7   8    9   10  11  12  13 14   15   16 17   18   19
              :hindrances      => [-20, 16, 25, 25, 16, 35, 21, 29, nil, 35, 21, 25, 21, 35, nil, nil, 10, nil, nil, nil],
              :hindrance_max   => 90,
              #                    AP  1    2    3    4    5    6    7    8    9    10   11   12   13   14   15   16  17   18   19
              :training_reqs   => [70, 210, 390, 390, 210, 590, 310, 470, nil, 590, 310, 390, 310, 590, 590, nil, 90, nil, nil, nil],
            },
            :asg_18 => {
              :type            => :plate,
              :base_name       => :augmented_plate,
              :all_names       => ["plate armor", "plate-and-mail", "augmented breastplate", "breastplate", "coracia", "cuirass", "platemail", "plate corslet", "plate corselet"],
              :armor_group     => 5,
              :armor_sub_group => 18,
              :base_weight     => 25,
              :min_rt          => 10,
              :action_penalty  => -25,
              :normal_cva      => -11,
              :magical_cva     => -19,
              #                    AP   1   2   3   4   5   6   7   8    9   10  11  12  13  14   15   16 17   18   19
              :hindrances      => [-25, 17, 28, 28, 18, 40, 24, 33, nil, 40, 21, 28, 21, 40, nil, nil, 11, nil, nil, nil],
              :hindrance_max   => 92,
              #                    AP  1    2    3    4    5    6    7    8    9    10   11   12   13   14   15   16  17   18   19
              :training_reqs   => [90, 230, 450, 450, 250, 690, 370, 550, nil, 690, 310, 450, 310, 690, 690, nil, 110, nil, nil, nil],
            },
            :asg_19 => {
              :type            => :plate,
              :base_name       => :half_plate,
              :all_names       => ["plate armor", "plate-and-mail", "half plate", "half-plate", "plate", "platemail"],
              :armor_group     => 5,
              :armor_sub_group => 19,
              :base_weight     => 50,
              :min_rt          => 11,
              :action_penalty  => -30,
              :normal_cva      => -12,
              :magical_cva     => -20,
              #                    AP   1   2   3   4   5   6   7   8    9   10  11  12  13  14   15   16 17   18   19
              :hindrances      => [-30, 18, 32, 32, 20, 45, 27, 39, nil, 45, 21, 32, 21, 45, nil, nil, 12, nil, nil, nil],
              :hindrance_max   => 94,
              #                    AP   1    2    3    4    5    6    7    8    9    10   11   12   13   14   15   16   17   18   19
              :training_reqs   => [110, 250, 530, 530, 290, 790, 430, 570, nil, 790, 310, 530, 310, 790, 790, nil, 130, nil, nil, nil],
            },
            :asg_20 => {
              :type            => :plate,
              :base_name       => :full_plate,
              :all_names       => ["plate armor", "plate-and-mail", "full plate", "full platemail", "body armor", "field plate", "field platemail", "lasktol'zko", "plate", "platemail"],
              :armor_group     => 5,
              :armor_sub_group => 20,
              :base_weight     => 75,
              :min_rt          => 12,
              :action_penalty  => -35,
              :normal_cva      => -13,
              :magical_cva     => -21,
              #                    AP   1   2   3   4   5   6   7   8    9   10  11  12  13  14   15   16 17   18   19
              :hindrances      => [-35, 20, 45, 45, 22, 50, 30, 48, nil, 50, 50, 45, 50, 50, nil, nil, 13, nil, nil, nil],
              :hindrance_max   => 96,
              #                    AP   1    2    3    4    5    6    7    8    9    10   11   12   13   14   15   16   17   18   19
              :training_reqs   => [130, 290, 850, 850, 330, 890, 490, 850, nil, 890, 890, 790, 890, 890, 890, nil, 150, nil, nil, nil],
            },
          },
        }

        Lich::Util.deep_freeze(@@armor_stats)

        ##
        # Returns the critical divisor used for determining damage reduction based on armor type,
        # armor group (AG), or armor subgroup (ASG).
        #
        # Priority is: `type` > `ag` > `asg`.
        #
        # @param type [Symbol, nil] The armor type (:cloth, :leather, :scale, :chain, :plate).
        # @param ag [Integer, nil] The armor group number (1 to 5).
        # @param asg [Integer, nil] The armor subgroup number (1 to 20).
        # @return [Integer] The critical divisor value for the given input.
        # @raise [ArgumentError] If none of `type`, `ag`, or `asg` are provided.
        def self.find_crit_divisor(type: nil, ag: nil, asg: nil)
          return { cloth: 5, leather: 6, scale: 7, chain: 9, plate: 11 }[type] unless type.nil?
          return { 1 => 5, 2 => 6, 3 => 7, 4 => 9, 5 => 11 }[ag] unless ag.nil?
          return ({ 1..4 => 5, 5..8 => 6, 9..12 => 7, 13..16 => 9, 17..20 => 11 }.find { |range, _| range.include?(asg) }&.last) unless asg.nil?
          raise ArgumentError, "Must provide either type, ag (armor group), or asg (armor sub-group) to find_crit_divisor"
        end

        ##
        # Returns the body coverage classification for a given armor subgroup number (ASG).
        #
        # Classifications include:
        #   - :torso
        #   - :torso_and_arms
        #   - :torso_arms_and_legs
        #   - :torso_arms_legs_and_head
        #
        # @param asg [Integer] The armor subgroup number (1 to 20).
        # @return [Symbol, nil] The body coverage classification, or nil if ASG is not found.
        def self.find_coverage(asg)
          return nil unless asg.is_a?(Integer) && asg.between?(1, 20)
          coverage = {
            torso: [1, 5, 9, 13, 17],
            torso_and_arms: [6, 10, 14, 18],
            torso_arms_and_legs: [7, 11, 15, 19],
            torso_arms_legs_and_head: [2, 8, 12, 16, 20],
          }

          coverage.each do |key, asgs|
            return key if asgs.include?(asg)
          end

          nil
        end

        ##
        # Finds the armor stats hash by ASG (Armor Sub Group) number.
        #
        # @param asg_number [Integer] The armor sub group number (ASG) to search for.
        # @return [Hash, nil] The stats hash of the matching armor, or nil if not found.
        def self.find_by_asg(asg_number)
          return nil unless asg_number.is_a?(Integer) && asg_number.between?(1, 20)

          @@armor_stats.each_value do |subgroups|
            subgroups.each do |_, asg_data|
              next unless asg_data.is_a?(Hash)
              return asg_data if asg_data[:armor_sub_group] == asg_number
            end
          end

          nil
        end

        ##
        # Returns a list of all recognized alternative and base armor names across all ASGs.
        #
        # @return [Array<String>] All valid armor names.
        def self.names
          @@armor_stats.flat_map do |_, subgroups|
            subgroups.values.compact.map { |asg| asg[:all_names] }
          end.flatten.compact.uniq
        end

        ##
        # Returns a sorted list of all unique armor type categories in the dataset.
        #
        # @return [Array<String>] List of armor type names (e.g., "Robes", "Light Leather", etc.)
        #
        def self.categories
          @@armor_stats.values.flat_map(&:values).map { _1[:base] }.uniq.compact
        end

        ##
        # Returns a list of all base armor names across all ASGs.
        #
        # @return [Array<String>] List of base armor names.
        #
        def self.base_names
          @@armor_stats.flat_map do |_, subgroups|
            subgroups.values.compact.map { |asg| asg[:base_name] }.uniq.compact
          end
        end

        ##
        # Returns the armor stats hash matching the given name from any armor group.
        # WARNING: Names are not strict, it could match multiple types of armor
        #
        # @param name [String] The name or alias of the armor.
        # @return [Array<Hash>] The full stats hash for the matching armor, or nil if not found.
        def self.find(name)
          name = name.downcase.strip

          matches = []
          @@armor_stats.each_value do |subgroups|
            subgroups.each_value do |asg_data|
              next unless asg_data.is_a?(Hash)
              matches << asg_data if asg_data[:all_names].include?(name)
            end
          end

          return matches.uniq unless matches.empty?
          return nil if matches.empty?
        end

        ##
        # Lists all armor stat blocks matching a specific armor type.
        #
        # @param type [Symbol] The armor type to filter by (e.g., :cloth, :leather, :chain).
        # @return [Array<Hash>] Array of armor stat hashes matching the given type.
        def self.list_by_type(type)
          @@armor_stats.flat_map do |_, subgroups|
            subgroups.values.compact.select { |asg| asg[:type] == type }
          end
        end

        ##
        # Returns all known name aliases for a specific armor ASG.
        #
        # This method is useful when you want to list the name variants associated
        # with a particular armor subgroup (ASG).
        #
        # @param asg [Integer, Symbol] the Armor Sub Group number (1–20) or symbol (e.g., :asg_18)
        # @return [Array<String>] list of all known aliases for the armor type, or an empty array if not found
        def self.names_in_asg(asg)
          asg_sym = asg.is_a?(Integer) ? :"asg_#{asg}" : asg.to_sym

          @@armor_stats.each_value do |subgroups|
            if subgroups.key?(asg_sym)
              return subgroups[asg_sym][:all_names] || []
            end
          end

          []
        end

        ##
        # Returns the armor type for the given name.
        #
        # This corresponds to the :type field in the armor entry, such as "rigid leather" or "full plate".
        #
        # @param name [String] the armor name or alias
        # @return [String, nil] the armor type, or nil if not found
        def self.category_for(name)
          name = name.downcase.strip

          armor = self.find(name)
          armor ? armor[:type] : nil
        end

        ##
        # Pretty-prints an armor's data by name in a compact, aligned table format.
        #
        # @param name [String] the name or alias of the armor
        # @return [String] formatted armor display string
        def self.pretty(name)
          armor = self.find(name)
          return "\n(no data)\n" unless armor.is_a?(Hash)

          lines = []
          lines << "" # leading blank

          asg = armor[:armor_sub_group]
          ag  = armor[:armor_group]
          type = armor[:type].to_s.capitalize

          lines << "Armor: #{armor[:all_names].first} (ASG #{asg}, AG #{ag}, #{type})"
          lines << "Weight: #{armor[:base_weight]} lbs    RT: #{armor[:min_rt]}s    AP: #{armor[:action_penalty]}    CVA: Norm #{armor[:normal_cva]} / Mag #{armor[:magical_cva]}"
          lines << "Hindrance Max: #{armor[:hindrance_max]}    Coverage: #{find_coverage(asg)}"
          lines << "Alternate Names: #{armor[:all_names].join(', ')}"

          # Determine column width and spacing
          labels = Armaments::SPELL_CIRCLE_INDEX_TO_NAME.map { |_, data| data[:abbr] }
          col_width = labels.map(&:length).max + 1 # Add space between columns
          label_pad = 19
          format_cell = ->(str) { "%#{col_width}s" % str }

          # Build rows
          label_row     = ' ' * label_pad + labels.map(&format_cell).join
          underline_row = ' ' * label_pad + labels.map { format_cell.call('---') }.join
          hind_row      = 'Hindrances:'.ljust(label_pad) + armor[:hindrances].map { |v| v.nil? ? '-' : v }.map(&format_cell).join
          train_row     = 'Training Reqs:'.ljust(label_pad) + armor[:training_reqs].map { |v| v.nil? ? '-' : v }.map(&format_cell).join

          lines << label_row
          lines << underline_row
          lines << hind_row
          lines << train_row
          lines << "" # trailing blank

          lines.join("\n")
        end

        ##
        # Pretty-prints detailed armor stats in a vertically aligned long format.
        #
        # @param name [String] the armor name or alias
        # @return [String] formatted armor display string
        def self.pretty_long(name)
          armor = self.find(name)
          return "\n(no data)\n" unless armor.is_a?(Hash)

          lines = []
          max_field_label_len = [
            "Cast vs Armor", "Alternate Names", "Hindrance Max", "Base Weight"
          ].concat(Armaments::SPELL_CIRCLE_INDEX_TO_NAME.values.map { |v| v[:name] }).map(&:length).max

          col_width = 12
          training_label_indent = max_field_label_len + 3 + col_width + 2

          fields = {
            "Type"            => armor[:type].to_s.capitalize,
            "ASG"             => armor[:armor_sub_group],
            "AG"              => armor[:armor_group],
            "Weight"          => "#{armor[:base_weight]} lbs",
            "RT"              => "#{armor[:min_rt]}s",
            "AP"              => armor[:action_penalty],
            "Hindrance Max"   => armor[:hindrance_max],
            "Coverage"        => find_coverage(armor[:armor_sub_group]),
            "Alternate Names" => armor[:all_names].join(", ")
          }

          fields.each do |label, value|
            lines << "%#{max_field_label_len}s: %s" % [label, value]
          end

          # CvA values
          lines << "%#{max_field_label_len}s:    Normal: %s" % ["Cast vs Armor", armor[:normal_cva]]
          lines << "%#{max_field_label_len}s     Magical: %s" % ["", armor[:magical_cva]]

          # Headers
          lines << " " * training_label_indent + "Training"
          lines << " " * (max_field_label_len + 3) + "%-#{col_width}s  %-#{col_width}s" % ["Hindrance", "Requirements"]
          lines << " " * (max_field_label_len + 3) + "%-#{col_width}s  %-#{col_width}s" % ["-" * col_width, "-" * col_width]

          # Values
          Armaments::SPELL_CIRCLE_INDEX_TO_NAME.each do |i, meta|
            label = meta[:name]
            hindrance = armor[:hindrances][i] if armor[:hindrances]
            training  = armor[:training_reqs][i] if armor[:training_reqs]

            hindrance_str = hindrance.nil? ? "-" : hindrance.to_s
            training_str  = training.nil? ? "-" : training.to_s

            lines << "%#{max_field_label_len}s: %#{col_width}s  %#{col_width}s" % [label, hindrance_str, training_str]
          end

          lines.join("\n")
        end

        ##
        # Returns all known aliases for the armor that matches the given name.
        #
        # @param name [String] the name or alias of the armor
        # @return [Array<String>] all aliases for the matching armor, or [] if not found
        def self.aliases_for(name)
          armor = self.find(name)
          armor ? armor[:all_names] : []
        end

        ##
        # Compares two armor types and returns key differences.
        #
        # @param name1 [String] first armor name
        # @param name2 [String] second armor name
        # @return [Hash, nil] comparison hash or nil if either armor not found
        def self.compare(name1, name2)
          a1 = self.find(name1)
          a2 = self.find(name2)
          return nil unless a1 && a2

          {
            name1: a1[:base_name],
            name2: a2[:base_name],
            weight: [a1[:base_weight], a2[:base_weight]],
            min_rt: [a1[:min_rt], a2[:min_rt]],
            ap: [a1[:action_penalty], a2[:action_penalty]],
            normal_cva: [a1[:normal_cva], a2[:normal_cva]],
            magical_cva: [a1[:magical_cva], a2[:magical_cva]],
            type: [a1[:type], a2[:type]],
            coverage: [find_coverage(a1[:armor_sub_group]), find_coverage(a2[:armor_sub_group])],
            aliases: [a1[:all_names], a2[:all_names]]
          }
        end

        ##
        # Searches armor entries using optional filters.
        #
        # @param filters [Hash] optional criteria:
        #   - :name [String]
        #   - :type [Symbol] (e.g., :leather, :chain)
        #   - :max_weight [Integer]
        #   - :min_cva [Integer]
        #   - :max_rt [Integer]
        #   - :min_ap [Integer]
        #   - :coverage [Symbol] (e.g., :torso_arms_and_legs)
        # @return [Array<Hash>] matching armor stat blocks
        def self.search(filters = {})
          @@armor_stats.values.flat_map(&:values).compact.select do |armor|
            next if filters[:name] && !armor[:all_names].include?(filters[:name].downcase.strip)
            next if filters[:type] && armor[:type] != filters[:type]
            next if filters[:max_weight] && armor[:base_weight] > filters[:max_weight]
            next if filters[:min_cva] && armor[:normal_cva] < filters[:min_cva]
            next if filters[:max_rt] && armor[:min_rt] > filters[:max_rt]
            next if filters[:min_ap] && armor[:action_penalty] < filters[:min_ap]
            next if filters[:coverage] && find_coverage(armor[:armor_sub_group]) != filters[:coverage]

            true
          end
        end

        ##
        # Checks if the provided name is a valid armor alias.
        #
        # Note that names for robes are very flexible, so this method
        # may not always return true for items that are robes
        #
        # @param name [String] the armor name to check
        # @return [Boolean] true if recognized
        def self.valid_name?(name)
          name = name.downcase.strip
          self.names.include?(name)
        end
      end
    end
  end
end
