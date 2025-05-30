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
              #                    0    1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :hindrances      => [nil, 0, 0, 0, 0, 0, 0, 0, nil, 0, 0, 0, 0, 0, nil, nil, 0, nil, nil, nil],
              :hindrance_max   => 0,
              #                    AP 1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :training_reqs   => [0, 0, 0, 0, 0, 0, 0, 0, nil, 0, 0, 0, 0, 0, nil, nil, 0, nil, nil, nil],
            },
            :asg_2 => {
              :type            => :cloth,
              :base_name       => :robes,
              :all_names       => ["robes", "robe"],
              :armor_group     => 1,
              :armor_sub_group => 2,
              :base_weight     => 8,
              :min_rt          => 0,
              :action_penalty  => 0,
              :normal_cva      => 25,
              :magical_cva     => 20,
              #                    0    1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :hindrances      => [nil, 0, 0, 0, 0, 0, 0, 0, nil, 0, 0, 0, 0, 0, nil, nil, 0, nil, nil, nil],
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
              #                    0    1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :hindrances      => [nil, 0, 0, 0, 0, 0, 0, 0, nil, 0, 0, 0, 0, 0, nil, nil, 0, nil, nil, nil],
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
              #                    0    1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :hindrances      => [nil, 0, 0, 0, 0, 0, 0, 0, nil, 0, 0, 0, 0, 0, nil, nil, 0, nil, nil, nil],
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
              #                    0    1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :hindrances      => [nil, 0, 0, 0, 0, 2, 0, 1, nil, 2, 0, 0, 0, 2, nil, nil, 0, nil, nil, nil],
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
              #                    0    1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :hindrances      => [nil, 0, 0, 0, 0, 4, 0, 2, nil, 4, 2, 0, 2, 4, nil, nil, 0, nil, nil, nil],
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
              #                    0    1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :hindrance       => [nil, 3, 4, 4, 4, 6, 3, 5, nil, 6, 3, 4, 4, 6, nil, nil, 2, nil, nil, nil],
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
              #                    0    1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :hindrance       => [nil, 4, 5, 5, 5, 7, 4, 6, nil, 7, 3, 5, 5, 7, nil, nil, 3, nil, nil, nil],
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
              #                    0    1  2  3  4  5  6  7  8    9  10 11 12 13 14   15   16 17   18   19
              :hindrance       => [nil, 5, 6, 6, 6, 9, 5, 8, nil, 9, 3, 6, 6, 9, nil, nil, 4, nil, nil, nil],
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
              #                    0    1  2  3  4  5   6  7   8    9   10 11 12 13  14   15   16 17   18   19
              :hindrances      => [nil, 6, 7, 7, 7, 12, 6, 11, nil, 12, 7, 7, 7, 12, nil, nil, 5, nil, nil, nil],
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
              #                    0    1  2  3  4  5   6  7   8    9   10 11 12 13  14   15   16 17   18   19
              :hindrances      => [nil, 7, 8, 8, 8, 16, 7, 16, nil, 16, 8, 8, 6, 16, nil, nil, 6, nil, nil, nil],
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
              #                    0    1  2  3  4  5   6  7   8    9   10 11 12 13  14   15   16 17   18   19
              :hindrances      => [nil, 8, 9, 9, 9, 20, 8, 18, nil, 20, 8, 9, 9, 20, nil, nil, 7, nil, nil, nil],
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
              #                    0    1  2   3   4   5   6  7   8    9   10 11  12  13  14   15   16 17   18   19
              :hindrances      => [nil, 9, 11, 11, 10, 25, 9, 22, nil, 25, 8, 11, 10, 25, nil, nil, 8, nil, nil, nil],
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
              #                    0    1   2   3   4   5   6   7   8    9   10  11  12  13  14   15   16 17   18   19
              :hindrances      => [nil, 11, 14, 14, 12, 30, 11, 26, nil, 30, 15, 14, 15, 30, nil, nil, 9, nil, nil, nil],
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
              :armor_group     => 2,
              :armor_sub_group => 5,
              :base_weight     => 23,
              :min_rt          => 9,
              :action_penalty  => -20,
              :normal_cva      => -10,
              :magical_cva     => -18,
              #                    0    1   2   3   4   5   6   7   8    9   10  11  12  13 14   15   16 17   18   19
              :hindrances      => [nil, 16, 25, 25, 16, 35, 21, 29, nil, 35, 21, 25, 21, 35, nil, nil, 10, nil, nil, nil],
              :hindrance_max   => 90,
              #                    AP  1    2    3    4    5    6    7    8    9    10   11   12   13   14   15   16  17   18   19
              :training_reqs   => [70, 210, 390, 390, 210, 590, 310, 470, nil, 590, 310, 390, 310, 590, 590, nil, 90, nil, nil, nil],
            },
            :asg_18 => {
              :type            => :plate,
              :base_name       => :augmented_plate,
              :all_names       => ["plate armor", "plate-and-mail", "augmented breastplate", "breastplate", "coracia", "cuirass", "platemail", "plate corslet", "plate corselet"],
              :armor_group     => 2,
              :armor_sub_group => 5,
              :base_weight     => 25,
              :min_rt          => 10,
              :action_penalty  => -25,
              :normal_cva      => -11,
              :magical_cva     => -19,
              #                    0    1   2   3   4   5   6   7   8    9   10  11  12  13  14   15   16 17   18   19
              :hindrances      => [nil, 17, 28, 28, 18, 40, 24, 33, nil, 40, 21, 28, 21, 40, nil, nil, 11, nil, nil, nil],
              :hindrance_max   => 92,
              #                    AP  1    2    3    4    5    6    7    8    9    10   11   12   13   14   15   16  17   18   19
              :training_reqs   => [90, 230, 450, 450, 250, 690, 370, 550, nil, 690, 310, 450, 310, 690, 690, nil, 110, nil, nil, nil],
            },
            :asg_19 => {
              :type            => :plate,
              :base_name       => :half_plate,
              :all_names       => ["plate armor", "plate-and-mail", "half plate", "half-plate", "plate", "platemail"],
              :armor_group     => 2,
              :armor_sub_group => 5,
              :base_weight     => 50,
              :min_rt          => 11,
              :action_penalty  => -30,
              :normal_cva      => -12,
              :magical_cva     => -20,
              #                    0    1   2   3   4   5   6   7   8    9   10  11  12  13  14   15   16 17   18   19
              :hindrances      => [nil, 18, 32, 32, 20, 45, 27, 39, nil, 45, 21, 32, 21, 45, nil, nil, 12, nil, nil, nil],
              :hindrance_max   => 94,
              #                    AP   1    2    3    4    5    6    7    8    9    10   11   12   13   14   15   16   17   18   19
              :training_reqs   => [110, 250, 530, 530, 290, 790, 430, 570, nil, 790, 310, 530, 310, 790, 790, nil, 130, nil, nil, nil],
            },
            :asg_20 => {
              :type            => :plate,
              :base_name       => :full_plate,
              :all_names       => ["plate armor", "plate-and-mail", "full plate", "full platemail", "body armor", "field plate", "field platemail", "lasktol'zko", "plate", "platemail"],
              :armor_group     => 2,
              :armor_sub_group => 5,
              :base_weight     => 75,
              :min_rt          => 12,
              :action_penalty  => -35,
              :normal_cva      => -13,
              :magical_cva     => -21,
              #                    0    1   2   3   4   5   6   7   8    9   10  11  12  13  14   15   16 17   18   19
              :hindrances      => [nil, 20, 45, 45, 22, 50, 30, 48, nil, 50, 50, 45, 50, 50, nil, nil, 13, nil, nil, nil],
              :hindrance_max   => 96,
              #                    AP   1    2    3    4    5    6    7    8    9    10   11   12   13   14   15   16   17   18   19
              :training_reqs   => [130, 290, 850, 850, 330, 890, 490, 850, nil, 890, 890, 790, 890, 890, 890, nil, 150, nil, nil, nil],
            },
          },
        }

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
          raise ArgumentError, "Must provide either type, ag, or asg to find_crit_divisor"
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
          coverage = {
            torso: [1, 2, 5, 9, 13, 17],
            torso_and_arms: [6, 10, 14, 18],
            torso_arms_and_legs: [7, 11, 15, 19],
            torso_arms_legs_and_head: [8, 12, 16, 20],
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
        def self.find_armor_by_asg(asg_number)
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
        def self.all_armor_names
          @@armor_stats.flat_map do |_, subgroups|
            subgroups.values.compact.map { |asg| asg[:all_names] }
          end.flatten.compact.uniq
        end

        ##
        # Returns the armor stats hash matching the given name from any armor group.
        # WARNING: Names are not strict, it could match multiple types of armor
        #
        # @param name [String] The name or alias of the armor.
        # @return [Hash, nil] The full stats hash for the matching armor, or nil if not found.
        def self.find_armor(name)
          normalized = Lich::Util.normalize_name(name)

          @@armor_stats.each_value do |subgroups|
            subgroups.each_value do |asg_data|
              next unless asg_data.is_a?(Hash)
              return asg_data if asg_data[:all_names].include?(normalized)
            end
          end
          nil
        end

        ##
        # Lists all armor stat blocks matching a specific armor type.
        #
        # @param type [Symbol] The armor type to filter by (e.g., :cloth, :leather, :chain).
        # @return [Array<Hash>] Array of armor stat hashes matching the given type.
        def self.list_armor_by_type(type)
          @@armor_stats.flat_map do |_, subgroups|
            subgroups.values.compact.select { |asg| asg[:type] == type }
          end
        end
      end
    end
  end
end
