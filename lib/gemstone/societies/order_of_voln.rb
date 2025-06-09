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
        # Some fields (e.g., `:summary`, `:duration`) may be defined as lambdas for dynamic content.
        # These are automatically resolved at access time via `Society.resolve`.
        #
        # @return [Hash<String, Hash>] Symbol name mapped to metadata
        #
        @@voln_symbols = {
          "symbol_of_recognition"   => {
            rank: 1,
            short_name: "recognition",
            long_name: "Symbol of Recognition",
            type: :utility,
            cost_modifier: 0.00,
            duration: nil,
            summary: "Detect other members of the Order and any undead creatures present in the room.",
            spell_number: 9801,
          },
          "symbol_of_blessing"      => {
            rank: 2,
            short_name: "blessing",
            long_name: "Symbol of Blessing",
            type: :utility,
            cost_modifier: 0.04, # 0.20 if magical
            alt_cost_modifier: 0.20, # TODO: Is this really a good solution?  Probably not.
            alt_cost_reason: "magical",
            duration: -> { Society.rank * 2 },
            summary: -> { "Bless weapons and other combat gear, up to 2x rank (+#{(Society.rank * 2)}) for Level + 2x Rank (#{Char.level + (Society.rank * 2)}) swings." },
            spell_number: 9802,
          },
          "symbol_of_thought"       => {
            rank: 3,
            short_name: "thought",
            long_name: "Symbol of Thought",
            type: :utility,
            cost_modifier: nil, ## TODO: should add the ability to calculate this based on message length
            duration: nil,
            summary: -> { "Transmit thought message to all members within the same realm.  Cost = ceiling((message length - 1) / 3)" },
            spell_number: 9803,
          },
          "symbol_of_diminishment"  => {
            rank: 4,
            short_name: "diminishment",
            long_name: "Symbol of Diminishment",
            type: :attack,
            cost_modifier: 0.30,
            duration: -> { Society.rank * 2 },
            summary: -> { "Successful SSR check will temporarily reduce target undead creature's DS, TD, and CMAN -1 per rank (#{Society.rank * 2}) for rank x 2 (#{Society.rank * 2}) seconds." },
            spell_number: 9804,
          },
          "symbol_of_courage"       => {
            rank: 5,
            short_name: "courage",
            long_name: "Symbol of Courage",
            type: :offense,
            cost_modifier: 0.10,
            duration: -> { Society.rank * 10 },
            summary: -> { "Increases your generic AS and UAF by +1 per rank (+#{Society.rank}).  Adds 3 phantom levels against fear-based attacks." },
            spell_number: 9805,
          },
          "symbol_of_protection"    => {
            rank: 6,
            short_name: "protection",
            long_name: "Symbol of Protection",
            type: :defense,
            cost_modifier: 0.10,
            duration: -> { Society.rank * 20 },
            summary: -> { "Increases your DS +1 and TD +.5 per rank (+#{Society.rank} DS / +#{(Society.rank * 0.5).floor} TD)." },
            spell_number: 9806,
          },
          "symbol_of_submission"    => {
            rank: 7,
            short_name: "submission",
            long_name: "Symbol of Submission",
            type: :attack,
            cost_modifier: 0.30,
            duration: nil,
            summary: "Successful SSR forces undead to offensive stance and to briefly kneel.",
            spell_number: 9807,
          },
          "kais_strike"             => {
            rank: 8,
            short_name: "strike",
            long_name: "Kai's Strike",
            type: :utility,
            cost_modifier: 0.00,
            duration: nil,
            summary: "Enables unarmed combat attacks to damage undead creatures without the normal requirement of blessed gear.",
            spell_number: 9808,
          },
          "symbol_of_holiness"      => {
            rank: 9,
            short_name: "holiness",
            long_name: "Symbol of Holiness",
            type: :attack,
            cost_modifier: 0.30,
            duration: nil,
            summary: "A SSR-based fire attack against an Undead creature.",
            spell_number: 9809,
          },
          "symbol_of_recall"        => {
            rank: 10,
            short_name: "recall",
            long_name: "Symbol of Recall",
            type: :utility,
            cost_modifier: 0.40,
            duration: nil,
            summary: "Restores spells after death.  Must be invoked while dead.  No effect for voluntary departs.",
            spell_number: 9810,
          },
          "symbol_of_sleep"         => {
            rank: 11,
            short_name: "sleep",
            long_name: "Symbol of Sleep",
            type: :attack,
            cost_modifier: 0.20, # base cost is 0.20, but it can be increased by the number of targets
            duration: nil,
            summary: "SSR-based targeted or mass disabling attack used against most creatures. Player friendly.",
            spell_number: 9811,
          },
          "symbol_of_transcendence" => {
            rank: 12,
            short_name: "transcendence",
            long_name: "Symbol of Transcendence",
            type: :defense,
            cost_modifier: 0.60,
            duration: 30,
            cooldown_duration: 180, # 3 minutes cooldown, or 10 minutes if used in an emergency, appear in effects??
            summary: "Take damage as if incorporeal for 30 seconds.  3m cooldown or 10 if used in an emergency.",
            spell_number: 9812,
          },
          "symbol_of_mana"          => {
            rank: 13,
            short_name: "mana",
            long_name: "Symbol of Mana",
            type: :utility,
            cost_modifier: 0.30,
            duration: nil,
            summary: "Restores 50 mana. Initially, no deed cost, 5 min cooldown.",
            spell_number: 9813,
          },
          "symbol_of_sight"         => {
            rank: 14,
            short_name: "sight",
            long_name: "Symbol of Sight",
            type: :utility,
            cost_modifier: 0.30,
            duration: 10,
            summary: "Locate voln member within range.",
            spell_number: 9814,
          },
          "symbol_of_retribution"   => {
            rank: 15,
            short_name: "retribution",
            long_name: "Symbol of Retribution",
            type: :attack,
            cost_modifier: 0.04, # attack version, 0.30 for selfcast
            duration: nil,
            summary: "SSR-based direct attack against undead when you are dead.  Living use grants SSR-based reactive flare when struck by undead.",
            spell_number: 9815,
          },
          "symbol_of_supremacy"     => {
            rank: 16,
            short_name: "supremacy",
            long_name: "Symbol of Supremacy",
            type: :offense,
            cost_modifier: 0.50,
            duration: -> { Society.rank * 10 },
            summary: -> { "Bonus of +1 per 2 ranks (+#{(Society.rank / 2).floor}) to AS/CS, CMAN, UAF against undead. for (#{Society.rank * 10}) seconds." },
            spell_number: 9816,
          },
          "symbol_of_restoration"   => {
            rank: 17,
            short_name: "restoration",
            long_name: "Symbol of Restoration",
            type: :utility,
            cost_modifier: 0.40,
            duration: nil,
            summary: "Restores half (10min/50max) hit points.",
            spell_number: 9817,
          },
          "symbol_of_need"          => {
            rank: 18,
            short_name: "need",
            long_name: "Symbol of Need",
            type: :utility,
            cost_modifier: 0.40,
            duration: nil,
            summary: "Transmits an image of the member's location to all other members within range.",
            spell_number: 9818,
          },
          "symbol_of_renewal"       => {
            rank: 19,
            short_name: "renewal",
            long_name: "Symbol of Renewal",
            type: :utility,
            cost_modifier: 0.50,
            duration: nil,
            cooldown_duration: 120, # 2 minutes cooldown
            summary: "Restores 1 Spirit Point. 2 min hard cooldown.",
            spell_number: 9819,
          },
          "symbol_of_disruption"    => {
            rank: 20,
            short_name: "disruption",
            long_name: "Symbol of Disruption",
            type: :attack,
            cost_modifier: 0.30, # Base cost is 0.30, but it can be increased by the number of targets
            duration: -> { Society.rank * 10 },
            summary: -> { "Group defense penalizing (AS/DS, CS/TD, UDF, CMAN) noncorporeal undead that are struck. Duration: #{Society.rank * 10} seconds stackable." },
            spell_number: 9820,
          },
          "kais_smite"              => {
            rank: 21,
            short_name: "smite",
            long_name: "Kai's Smite",
            type: :attack,
            cost_modifier: 0.00,
            duration: nil,
            summary: "Temporarily make a non-corporeal undead creature corporeal and more susceptible to damage using SMITE (unarmed attack).",
            spell_number: 9821,
            usage: "smite",
          },
          "symbol_of_turning"       => {
            rank: 22,
            short_name: "turning",
            long_name: "Symbol of Turning",
            type: :attack,
            cost_modifier: 0.30, # Base cost is 0.30, but it can be increased by the number of targets
            duration: nil,
            summary: "Targeted or mass SSR-based attack similar to fear effects with possible instant death result.",
            spell_number: 9822,
          },
          "symbol_of_preservation"  => {
            rank: 23,
            short_name: "preservation",
            long_name: "Symbol of Preservation",
            type: :utility,
            cost_modifier: 0.60,
            duration: nil, ## TODO: try to figure this out?
            summary: "Lifekeep. Can be used on self and other characters.",
            spell_number: 9823,
          },
          "symbol_of_dreams"        => {
            rank: 24,
            short_name: "dreams",
            long_name: "Symbol of Dreams",
            type: :utility,
            cost_modifier: 0.60,
            duration: nil, ## TODO: try to figure this out?
            summary: "Dream state - increases recovery of health, mana, spirit and reduced stats from Death's Sting.",
            spell_number: 9824,
          },
          "symbol_of_return"        => {
            rank: 25,
            short_name: "return",
            long_name: "Symbol of Return",
            type: :utility,
            cost_modifier: 1.00,
            duration: nil,
            summary: "Immediate Teleportation of member and group to the nearest Voln outpost.",
            spell_number: 9825,
          },
          "symbol_of_seeking"       => {
            rank: 26,
            short_name: "seeking",
            long_name: "Symbol of Seeking",
            type: :utility,
            cost_modifier: 0.00,
            duration: nil,
            summary: "Teleportation of group from a Voln outpost to an undead hunting area.",
            spell_number: 9826,
          },
        }.freeze

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
        # Retrieves a symbol definition by short or long name.
        #
        # Normalizes the provided name and attempts to match against both short and long names
        # of all Order of Voln symbols. Returns the corresponding symbol metadata if found.
        #
        # @param name [String] The short or long name of the symbol
        # @return [Hash, nil] The symbol metadata, or nil if not found
        #
        def self.[](name)
          raw = Society.lookup(name, @@voln_symbols, symbol_lookups)
          return nil unless raw

          raw.transform_values { |v| Society.resolve(v) }
        end

        ##
        # Returns all Order of Voln symbol metadata entries with evaluated fields.
        #
        # @return [Array<Hash>] An array of symbol metadata hashes with lambdas resolved
        #
        def self.all
          @@voln_symbols.values.map { |entry| entry.transform_values { |v| Society.resolve(v) } }
        end

        ##
        # Calculates the favor cost of a symbol based on the character's level.
        #
        # @param symbol_name [String] Long or short name of the symbol
        # @return [Integer] The rounded-up favor cost
        #
        def self.calculate_cost(symbol_name)
          symbol = self[symbol_name]
          return 0 unless symbol && symbol[:cost_modifier]

          base_cost = BASE_FAVOR_COST_BY_LEVEL[Char.level]
          (base_cost * symbol[:cost_modifier].to_f).ceil
        end

        ##
        # Returns a summary of symbol lookups including rank and favor cost.
        #
        # @return [Array<Hash>] An array of symbol metadata with favor cost
        #
        def self.symbol_lookups
          @@voln_symbols.map do |_, symbol|
            {
              long_name: symbol[:long_name],
              short_name: symbol[:short_name],
              rank: symbol[:rank],
              cost: calculate_cost(symbol[:short_name])
            }
          end
        end

        ##
        # Determines if the character knows a given symbol based on their rank.
        #
        # @param symbol_name [String] Long or short name of the symbol
        # @return [Boolean] True if the symbol is known (rank unlocked)
        #
        def self.known?(symbol_name)
          symbol = self[symbol_name]
          return false unless symbol

          symbol[:rank] <= self.rank
        end

        ##
        # Attempts to use a symbol by issuing the `symbol of <name>` command.
        #
        # @param symbol_name [String] Long or short name of the symbol
        # @param target [String, nil] Optional target to append
        # @raise [RuntimeError] If the symbol is not available
        #
        def self.use(symbol_name, target = nil)
          symbol = self[symbol_name]
          raise "Unknown symbol: #{symbol_name}" unless symbol

          if self.available?(symbol_name)
            command = symbol[:usage] || "symbol of #{symbol[:short_name]}"
            fput "#{command} #{target}".strip
          else
            raise "You cannot use the #{symbol_name} symbol right now." ## TODO: do we really want to raise an error here?
          end
        end

        ##
        # Checks if the character has enough favor to use a given symbol.
        #
        # @param symbol_name [String] Long or short name of the symbol
        # @return [Boolean] True if the character has enough favor
        #
        def self.affordable?(symbol_name)
          symbol = self[symbol_name]
          return false unless symbol
          favor >= calculate_cost(symbol_name)
        end

        ##
        # Determines if a symbol is both known and affordable (but not currently on cooldown).
        #
        # @param symbol_name [String] Long or short name of the symbol
        # @return [Boolean] True if the symbol is usable
        #
        def self.available?(symbol_name)
          self.known?(symbol_name) && self.affordable?(symbol_name)
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
          unless Society.membership == "Order of Voln"
            return false
          end

          rank.nil? || Society.rank == rank
        end

        ##
        # Dynamically defines singleton methods for each Order of Voln symbol.
        #
        # Each method allows accessing the symbol's metadata by calling either its
        # short name or long name as a method. For example:
        #
        #   OrderOfVoln.defense  #=> metadata hash for "Symbol of Defense"
        #   OrderOfVoln["Symbol of Defense"] #=> same result
        #
        # This supports both `symbol[:short_name]` and `symbol[:long_name]`.
        #
        define_name_methods(self, @@voln_symbols)
      end
    end
  end
end
