module Lich
  module Gemstone
    module Society
      ##
      # Represents the Order of Voln society.
      #
      # Provides access to Order of Voln symbol data, favor cost calculation, usability checks,
      # and dynamic method access for individual symbols.
      #
      class OrderOfVoln < Society
        # Calculate Cost of Symbol using data from here # https://gswiki.play.net/Favor#Symbol_Use_Favor_Cost

        ##
        # Metadata for each Symbol from the Order of Voln, including rank, type, cost modifier, duration, etc.
        #
        # @return [Hash<String, Hash>] Symbol name mapped to metadata
        #
        @@voln_symbols = {
          "symbol_of_recognition"   => {
            :rank              => 1,
            :short_name        => "recognition",
            :type              => :utility,
            :regex             => nil,
            :cost_modifier     => 0.00,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Detect other members of the Order and any undead creatures present in the room.",
            :spell_number      => 9801,
          },
          "symbol_of_blessing"      => {
            :rank              => 2,
            :short_name        => "blessing",
            :type              => :utility,
            :regex             => nil,
            :cost_modifier     => 0.04, # 0.20 if magical
            :alt_cost_modifier => 0.20, # TODO: Is this really a good solution?  Probably not.
            :alt_cost_reason   => "magical",
            :duration          => self.rank * 2,
            :cooldown_duration => nil,
            :summary           => "Bless weapons and other combat gear, upto 2x rank (+#{(self.rank * 2)}) for Level + 2x Rank (#{Char.level + (self.rank * 2)}) swings.",
            :spell_number      => 9802,
          },
          "symbol_of_thought"       => {
            :rank              => 3,
            :short_name        => "thought",
            :type              => :utility,
            :regex             => nil,
            :cost_modifier     => nil,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Transmit thought message to all members within the same realm.  Cost = ceiling((messsage length - 1) / 3)",
            :spell_number      => 9803,
          },
          "symbol_of_diminishment"  => {
            :rank              => 4,
            :short_name        => "diminishment",
            :type              => :attack,
            :regex             => nil,
            :cost_modifier     => 0.30,
            :duration          => self.rank * 2,
            :cooldown_duration => nil,
            :summary           => "Successful SSR check will temporarily reduces target undead creature's DS, TD, and CMAN -1 per rank (#{self.rank * 2}) for rank x 2 (#{self.rank * 2}) seconds.",
            :spell_number      => 9804,
          },
          "symbol_of_courage"       => {
            :rank              => 5,
            :short_name        => "courage",
            :type              => :offense,
            :regex             => nil,
            :cost_modifier     => 0.10,
            :duration          => self.rank * 10,
            :cooldown_duration => nil,
            :summary           => "Increases your generic AS and UAF by +1 per rank (+#{self.rank}).  Adds 3 phantom levels against fear-based attacks.",
            :spell_number      => 9805,
          },
          "symbol_of_protection"    => {
            :rank              => 6,
            :short_name        => "protection",
            :type              => :defense,
            :regex             => nil,
            :cost_modifier     => 0.10,
            :duration          => self.rank * 20,
            :cooldown_duration => nil,
            :summary           => "Increases your DS +1 and TD +.5 per rank (+#{self.rank} DS / +#{(self.rank * 0.5).floor} TD).",
            :spell_number      => 9806,
          },
          "symbol_of_submission"    => {
            :rank              => 7,
            :short_name        => "submission",
            :type              => :attack,
            :regex             => nil,
            :cost_modifier     => 0.30,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Successful SSR forces undead to offensive stance and to briefly kneel.",
            :spell_number      => 9807,
          },
          "kai's strike"            => {
            :rank              => 8,
            :short_name        => "strike",
            :type              => :utility,
            :regex             => nil,
            :cost_modifier     => 0.00,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Enables unarmed combat attacks to damage undead creatures without the normal requirement of blessed gear.",
            :spell_number      => 9808,
          },
          "symbol_of_holiness"      => {
            :rank              => 9,
            :short_name        => "holiness",
            :type              => :attack,
            :regex             => nil,
            :cost_modifier     => 0.30,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "A SSR-based fire attack against an Undead creature.",
            :spell_number      => 9809,
          },
          "symbol_of_recall"        => {
            :rank              => 10,
            :short_name        => "recall",
            :type              => :utility,
            :regex             => nil,
            :cost_modifier     => 0.40,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Restores spells after death.  Must be invoked while dead.  No effect for volunary departs.",
            :spell_number      => 9810,
          },
          "symbol_of_sleep"         => {
            :rank              => 11,
            :short_name        => "sleep",
            :type              => :attack,
            :regex             => nil,
            :cost_modifier     => 0.20, # base cost is 0.20, but it can be increased by the number of targets
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "SSR-based targeted or mass disabling attack used against most creatures. Player friendly.",
            :spell_number      => 9811,
          },
          "symbol_of_transcendence" => {
            :rank              => 12,
            :short_name        => "transcendence",
            :type              => :defense,
            :regex             => nil,
            :cost_modifier     => 0.60,
            :duration          => 30,
            :cooldown_duration => 180, # 3 minutes cooldown, or 10 minutes if used in an emergency
            :summary           => "Take damage as if incorporeal for 30 seconds.  3m cooldown or 10 if used in an emergency.",
            :spell_number      => 9812,
          },
          "symbol_of_mana"          => {
            :rank              => 13,
            :short_name        => "mana",
            :type              => :utility,
            :regex             => nil,
            :cost_modifier     => 0.30,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Restores 50 mana. Initially, no deed cost, 5 min cooldown.",
            :spell_number      => 9813,
          },
          "symbol_of_sight"         => {
            :rank              => 14,
            :short_name        => "sight",
            :type              => :utility,
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
            :type              => :attack,
            :regex             => nil,
            :cost_modifier     => 0.04, # attack version, 0.30 for selfcast
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "SSR-based direct attack against undead when you are dead.  Living use grants SSR-based reactive flare when struck by undead.",
            :spell_number      => 9815,
          },
          "symbol_of_supremacy"     => {
            :rank              => 16,
            :short_name        => "supremacy",
            :type              => :offense,
            :regex             => nil,
            :cost_modifier     => 0.50,
            :duration          => self.rank * 10,
            :cooldown_duration => nil,
            :summary           => "Bonus of +1 per 2 ranks (+#{(self.ranks / 2).floor}) to AS/CS, CMAN, UAF against undead. for (#{self.rank * 10}) seconds.",
            :spell_number      => 9816,
          },
          "symbol_of_restoration"   => {
            :rank              => 17,
            :short_name        => "restoration",
            :type              => :utility,
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
            :type              => :utility,
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
            :type              => :utility,
            :regex             => nil,
            :cost_modifier     => 0.50,
            :duration          => nil,
            :cooldown_duration => 120, # 2 minutes cooldown
            :summary           => "Restores 1 Spirit Point. 2 min hard cooldown.",
            :spell_number      => 9819,
          },
          "symbol_of_disruption"    => {
            :rank              => 20,
            :short_name        => "disruption",
            :type              => :attack,
            :regex             => nil,
            :cost_modifier     => 0.30, # Base cost is 0.30, but it can be increased by the number of targets
            :duration          => self.rank * 10,
            :cooldown_duration => nil,
            :summary           => "Group defense penalizing (AS/DS, CS/TD, UDF, CMAN) noncorporeal undead that are struck. Duration: #{self.rank * 10} seconds stackable.",
            :spell_number      => 9820,
          },
          "kai's smite"             => {
            :rank              => 21,
            :short_name        => "smite",
            :type              => :attack,
            :regex             => nil,
            :cost_modifier     => 0.00,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Temporarily make a non-corporeal undead creature corporeal and more susceptible to damage using SMITE (unarmed attack).",
            :spell_number      => 9821,
            :usage             => "smite",
          },
          "symbol_of_turning"       => {
            :rank              => 22,
            :short_name        => "turning",
            :type              => :attack,
            :regex             => nil,
            :cost_modifier     => 0.30, # Base cost is 0.30, but it can be increased by the number of targets
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Targeted or mass SSR-based attack similar to fear effects with possible instant death result.",
            :spell_number      => 9822,
          },
          "symbol_of_preservation"  => {
            :rank              => 23,
            :short_name        => "preservation",
            :type              => :utility,
            :regex             => nil,
            :cost_modifier     => 0.60,
            :duration          => nil, ## TODO: try to figure this out?
            :cooldown_duration => nil,
            :summary           => "Lifekeep. Can be used on self and other characters.",
            :spell_number      => 9823,
          },
          "symbol_of_dreams"        => {
            :rank              => 24,
            :short_name        => "dreams",
            :type              => :utility,
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
            :type              => :utility,
            :regex             => nil,
            :cost_modifier     => 1.00,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Immediate Teleportation of member and group to the nearest Voln outpost.",
            :spell_number      => 9825,
          },
          "symbol_of_seeking"       => {
            :rank              => 26,
            :short_name        => "seeking",
            :type              => :utility,
            :regex             => nil,
            :cost_modifier     => 0.00,
            :duration          => nil,
            :cooldown_duration => nil,
            :summary           => "Teleportation of group from a Voln outpost to an undead hunting area.",
            :spell_number      => 9826,
          },
        }

        ##
        # Favor cost required to use each symbol by character level (indexed by level).
        #
        # @return [Array<Integer>] Favor cost per level
        #
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

        ##
        # Retrieves a symbol definition by its short name.
        #
        # @param short_name [String] The short name of the symbol
        # @return [Hash, nil] The symbol metadata, or nil if not found
        #
        def self.[](short_name)
          normalized_name = Lich::Utils.normalize_name(short_name)
          @@voln_symbols.values.find { |s| s[:short_name] == normalized_name }
        end

        ##
        # Calculates the favor cost of a symbol based on the character's level.
        #
        # @param _symbol_name [String] The short name of the symbol
        # @return [Integer] The rounded-up favor cost
        #
        def self.calculate_cost(symbol_name)
          normalized_name = Lich::Utils.normalize_name(symbol_name)

          symbol = @@voln_symbols[normalized_name]
          return 0 unless symbol

          base_cost = BASE_FAVOR_COST_BY_LEVEL[Char.level]
          (base_cost * symbol[:cost_modifier].to_f).ceil
        end

        ##
        # Returns a summary of symbol lookups including rank and favor cost.
        #
        # @return [Array<Hash>] An array of symbol metadata with favor cost
        #
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

        ##
        # Determines if the character knows a given symbol based on their rank.
        #
        # @param symbol_name [String] The long name of the symbol
        # @return [Boolean] True if the symbol is known (rank unlocked)
        #
        def self.known?(symbol_name)
          normalized_name = Lich::Utils.normalize_name(symbol_name)

          @@voln_symbols[normalized_name][:rank] <= self.rank
        end

        ##
        # Attempts to use a symbol by issuing the `symbol of <name>` command.
        #
        # @param symbol_name [String] The symbol to invoke
        # @raise [RuntimeError] If the symbol is not available
        #
        def self.use(symbol_name, target = nil)
          normalized_name = Lich::Utils.normalize_name(symbol_name)

          if self.available?(normalized_name)
            if @@voln_symbols[normalized_name][:usage]
              fput "#{@@voln_symbols[normalized_name][:usage]} #{target}".strip
            else
              fput "symbol of #{@@voln_symbols[normalized_name][:short_name]} #{target}".strip
            end
          else
            raise "You cannot use the #{symbol_name} symbol right now." ## Temp
          end
        end

        ##
        # Checks if the character has enough favor to use a given symbol.
        #
        # @param symbol_name [String] The symbol's long name
        # @return [Boolean] True if the character has enough favor
        #
        def self.affordable?(symbol_name)
          normalized_name = Lich::Utils.normalize_name(symbol_name)

          favor >= calculate_cost(normalized_name)
        end

        ##
        # Determines if a symbol is both known and affordable (but not currently on cooldown).
        #
        # @param symbol_name [String] The symbol's long name
        # @return [Boolean] True if the symbol is usable
        #
        def self.available?(symbol_name)
          normalized_name = Lich::Utils.normalize_name(symbol_name)

          self.known?(normalized_name) && self.affordable?(normalized_name) # and check for cooldowns
        end

        ##
        # Gets the character's current Voln favor.
        #
        # @return [Integer, nil] The favor amount or nil if not available
        #
        def self.favor
          Infomon.get('resources.voln_favor')
        end

        ##
        # Checks if the character is a Voln master (rank 26).
        #
        # @return [Boolean] True if the character has achieved master rank
        #
        def self.master?
          Society.rank == 26 # is the rank of a Voln Master
        end

        ##
        # Checks if the character is a member of Voln and optionally at a given rank.
        #
        # @param rank [Integer, nil] Optionally check if the character is at this rank
        # @return [Boolean] True if the character is a Voln member (and at the specified rank, if given)
        #
        def self.member?(rank = nil)
          unless Society.member_of == "Order of Voln"
            return false
          end

          rank.nil? || Society.rank == rank
        end

        # Dynamically define accessors for each symbol using its long and short names
        OrderOfVoln.symbol_lookups.each { |symbol|
          self.define_singleton_method(symbol[:short_name]) do
            OrderOfVoln[symbol[:short_name]]
          end

          self.define_singleton_method(symbol[:long_name]) do
            OrderOfVoln[symbol[:short_name]]
          end
        }
      end
    end
  end
end
