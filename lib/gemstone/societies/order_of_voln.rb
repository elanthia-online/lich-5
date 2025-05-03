module Lich
  module Gemstone
    module Society
      class Voln < Society
        # Calculate Cost of Symbol
        # https://gswiki.play.net/Favor#Symbol_Use_Favor_Cost
        @@voln_symbols = {
          "symbol_of_recognition"   => {
            :rank              => 1,
            :short_name        => "recognition",
            :regex             => nil,
            :cost_modifier     => 0.00,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Identifies members of the Order and any undead present.",
            :spell_number      => 9801,
          },
          "symbol_of_blessing"      => {
            :rank              => 2,
            :short_name        => "blessing",
            :regex             => nil,
            :cost_modifier     => 0.04, # 0.20 if magical
            :duration          => self.rank * 2,
            :cooldown_duration => nil,
            :summary           => "Bless weapons and other combat gear.",
            :spell_number      => 9802,
          },
          "symbol_of_thought"       => {
            :rank              => 3,
            :short_name        => "thought",
            :regex             => nil,
            :cost_modifier     => 0.00,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Transmit thought message to all members within range.",
            :spell_number      => 9803,
          },
          "symbol_of_diminishment"  => {
            :rank              => 4,
            :short_name        => "diminishment",
            :regex             => nil,
            :cost_modifier     => 0.30,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Temporarily reduces target undead creature's DS, TD, and CMAN -1 per rank.",
            :spell_number      => 9804,
          },
          "symbol_of_courage"       => {
            :rank              => 5,
            :short_name        => "courage",
            :regex             => nil,
            :cost_modifier     => 0.10,
            :duration          => self.rank * 10,
            :cooldown_duration => nil,
            :summary           => "Increases your AS +1 per rank (+#{self.rank}).",
            :spell_number      => 9805,
          },
          "symbol_of_protection"    => {
            :rank              => 6,
            :short_name        => "protection",
            :regex             => nil,
            :cost_modifier     => 0.10,
            :duration          => self.rank * 20,
            :cooldown_duration => nil,
            :summary           => "Increases your DS +1 and TD +.5 per rank (+#{self.Rank} DS / +#{(self.Rank * 0.5)} TD).",
            :spell_number      => 9806,
          },
          "symbol_of_submission"    => {
            :rank              => 7,
            :short_name        => "submission",
            :regex             => nil,
            :cost_modifier     => 0.30,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Forces undead to offensive stance and lowers DS -1 per rank (-#{self.Rank}).",
            :spell_number      => 9807,
          },
          "kai's strike"            => {
            :rank              => 8,
            :short_name        => "strike",
            :regex             => nil,
            :cost_modifier     => 0.00,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Allows unarmed combat attacks to damage undead creatures.",
            :spell_number      => 9808,
          },
          "symbol_of_holiness"      => {
            :rank              => 9,
            :short_name        => "holiness",
            :regex             => nil,
            :cost_modifier     => 0.30,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Direct damage attack against undead.",
            :spell_number      => 9809,
          },
          "symbol_of_recall"        => {
            :rank              => 10,
            :short_name        => "recall",
            :regex             => nil,
            :cost_modifier     => 0.40,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Restores spells after death.  Must be invoked while dead.",
            :spell_number      => 9810,
          },
          "symbol_of_sleep"         => {
            :rank              => 11,
            :short_name        => "sleep",
            :regex             => nil,
            :cost_modifier     => 0.20, # base cost is 0.20, but it can be increased by the number of targets
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Targeted or mass disabling attack used against most creatures.",
            :spell_number      => 9811,
          },
          "symbol_of_transcendence" => {
            :rank              => 12,
            :short_name        => "transcendence",
            :regex             => nil,
            :cost_modifier     => 0.60,
            :duration          => 30,
            :cooldown_duration => nil,
            :summary           => "Take damage as if incorporeal.",
            :spell_number      => 9812,
          },
          "symbol_of_mana"          => {
            :rank              => 13,
            :short_name        => "mana",
            :regex             => nil,
            :cost_modifier     => 0.30,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Restores 15 mana. Initially, no deed cost, 3 min cooldown.",
            :spell_number      => 9813,
          },
          "symbol_of_sight"         => {
            :rank              => 14,
            :short_name        => "sight",
            :regex             => nil,
            :cost_modifier     => 0.30,
            :duration          => 10,
            :cooldown_duration => nil,
            :summary           => "Locate voln member within range.",
            :spell_number      => 9814,
          },
          "symbol_of_retribution"   => {
            :rank              => 15,
            :short_name        => "retribution",
            :regex             => nil,
            :cost_modifier     => 0.04, # attack version, 0.30 for selfcast
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Direct attack against undead when you are dead.",
            :spell_number      => 9815,
          },
          "symbol_of_supremacy"     => {
            :rank              => 16,
            :short_name        => "supremacy",
            :regex             => nil,
            :cost_modifier     => 0.50,
            :duration          => self.rank * 10,
            :cooldown_duration => nil,
            :summary           => "Bonus of +1 per 2 ranks (+#{self.ranks / 2}) to AS/CS, CMAN, UAF against undead.", ## TODO: Need to round this properly
            :spell_number      => 9816,
          },
          "symbol_of_restoration"   => {
            :rank              => 17,
            :short_name        => "restoration",
            :regex             => nil,
            :cost_modifier     => 0.40,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Restores half (10min/50max) hit points.",
            :spell_number      => 9817,
          },
          "symbol_of_need"          => {
            :rank              => 18,
            :short_name        => "need",
            :regex             => nil,
            :cost_modifier     => 0.40,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Transmits an image of the member's location to all other members within range.",
            :spell_number      => 9818,
          },
          "symbol_of_renewal"       => {
            :rank              => 19,
            :short_name        => "renewal",
            :regex             => nil,
            :cost_modifier     => 0.50,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Restores 1 Spirit Point. 2 min hard cooldown.",
            :spell_number      => 9819,
          },
          "symbol_of_disruption"    => {
            :rank              => 20,
            :short_name        => "disruption",
            :regex             => nil,
            :cost_modifier     => 0.30, # Base cost is 0.30, but it can be increased by the number of targets
            :duration          => self.rank * 10,
            :cooldown_duration => nil,
            :summary           => "Group defense penalizing uncorporeal undead that are struck.",
            :spell_number      => 9820,
          },
          "kai's smite"             => {
            :rank              => 21,
            :short_name        => "smite",
            :regex             => nil,
            :cost_modifier     => nil,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Temporarily makea non-corporeal undead creature corporeal using SMITE (unarmed attack).",
            :spell_number      => 9821,
          },
          "symbol_of_turning"       => {
            :rank              => 22,
            :short_name        => "turning",
            :regex             => nil,
            :cost_modifier     => 0.30, # Base cost is 0.30, but it can be increased by the number of targets
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Targeted or mass attack similar to fear effects with possible instant death result.",
            :spell_number      => 9822,
          },
          "symbol_of_preservation"  => {
            :rank              => 23,
            :short_name        => "preservation",
            :regex             => nil,
            :cost_modifier     => 0.60,
            :duration          => nil, ## TODO: try to figure this out?
            :cooldown_duration => nil,
            :summary           => "Self Lifekeep. Can also be used on other characters.",
            :spell_number      => 9823,
          },
          "symbol_of_dreams"        => {
            :rank              => 24,
            :short_name        => "dreams",
            :regex             => nil,
            :cost_modifier     => 0.60,
            :duration          => nil, ## TODO: try to figure this out?
            :cooldown_duration => nil,
            :summary           => "Dream state - increass recovery of health, mana, spirit and reduced stats from Death's Sting.",
            :spell_number      => 9824,
          },
          "symbol_of_return"        => {
            :rank              => 25,
            :short_name        => "return",
            :regex             => nil,
            :cost_modifier     => nil, ## TODO: try to figure this out?  Is this right?
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Immediate Teleportation of member and group to the nearest Voln outpost.",
            :spell_number      => 9825,
          },
          "symbol_of_seeking"       => {
            :rank              => 26,
            :short_name        => "seeking",
            :regex             => nil,
            :cost_modifier     => nil,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Teleportation of group from a Voln outpost to an undead hunting area.",
            :spell_number      => 9826,
          },
        }

        BASE_FAVOR_COST_BY_LEVEL = [
          nil, nil, nil, 13, 22, 32, 43, 56, 70, 85, 100, 117, 134, 151, 169, 188,
          207, 226, 246, 266, 286, 307, 328, 349, 370, 391, 412, 434, 456, 478,
          500, 522, 544, 577, 590, 613, 636, 659, 682, 705, 728, 751, 774, 797,
          820, 843, 866, 889, 912, 935, 958, 981, 1004, 1027, 1050, 1073, 1097,
          1121, 1145, 1169, 1193, 1217, 1241, 1265, 1289, 1313, 1337, 1361, 1385,
          1409, 1433, 1457, 1481, 1505, 1529, 1553, 1577, 1601, 1625, 1649, 1674,
          1699, 1724, 1749, 1774, 1799, 1824, 1849, 1874, 1899, 1924, 1949, 1974,
          1999, 2024, 2049, 2074, 2099, 2124, 2149, 2174
        ]

        def self.[](short_name)
          @@voln_symbols.values.find { |s| s[:short_name] == short_name }
        end

        def self.calculate_cost(_symbol_name)
          (BASE_FAVOR_COST_BY_LEVEL[Char.level] * symbol[:cost_modifier].to_f).ceil ## TODO: Double check this is the proper rounding
        end

        # symbol_lookups
        def self.symbol_lookups
          @@voln_symbols.map do |long_name, symbol|
            {
              long_name: long_name,
              short_name: symbol[:short_name],
              rank: symbol[:rank],
              cost: calculate_cost(symbol[:short_name])
            }
          end
        end

        # known?
        def self.known?(symbol_name)
          @@voln_symbols[symbol_name.downcase][:rank] <= self.rank
        end

        # use
        def self.use(symbol_name)
          if self.available?(symbol_name)
            fput "symbol of #{symbol_name}" # TODO: Implement this properly
          else
            raise "You cannot use the #{symbol_name} symbol right now." ## Temp
          end
        end

        # affordable?
        def self.affordable?(symbol_name)
          @@voln_symbols[symbol_name.downcase][:cost] <= self.favor
        end

        # available?
        def self.available?(symbol_name)
          self.known?(symbol_name) && self.affordable?(symbol_name) # and check for cooldowns
        end

        # favor
        def self.favor
          Infomon.get('resources.voln_favor')
        end

        # master?
        def self.master?
          self.rank == 26 # is the rank of a Voln Master
        end

        Voln.symbol_lookups.each { |symbol|
          self.define_singleton_method(symbol[:short_name]) do
            Voln[symbol[:short_name]]
          end

          self.define_singleton_method(symbol[:long_name]) do
            Voln[symbol[:short_name]]
          end
        }
      end
    end
  end
end
