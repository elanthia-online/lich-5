module Lich
  module Gemstone
    module Society
      ##
      # Represents the Council of Light society.
      #
      # Provides access to CoL sign data, cost handling, usability checks, and sign commands.
      #
      class CouncilOfLight < Society
        ##
        # Metadata for each Sign from the Council of Light, including rank, cost, duration, etc.
        #
        # @return [Hash<String, Hash>] Sign long name mapped to metadata
        @@col_signs = {
          "sign_of_recognition"  => {
            rank: 1,
            short_name: "recognition",
            type: :utility,
            regex: nil,
            cost: { spirit: 0, mana: 0 },
            cost_type: nil,
            duration: nil,
            cooldown_duration: nil,
            summary: "Allows the character to identify other members and their relative ranks.",
            spell_number: 9901,
          },
          "sign_of_signal"       => {
            rank: 2,
            short_name: "signal",
            type: :utility,
            regex: nil,
            cost: { spirit: 0, mana: 0 },
            cost_type: nil,
            duration: nil,
            cooldown_duration: nil,
            summary: "Use sign language to communicate with other society members in the room.",
            spell_number: 9902,
            usage: "signal"
          },
          "sign_of_warding"      => {
            rank: 3,
            short_name: "warding",
            type: :defense,
            regex: nil,
            cost: { spirit: 0, mana: 1 },
            cost_type: :invoked,
            duration: 10 * Char.level,
            cooldown_duration: nil,
            summary: "Increases Defensive Strength by +5 for 10 seconds/level (#{10 * Char.level}).",
            spell_number: 9903,
          },
          "sign_of_striking"     => {
            rank: 4,
            short_name: "striking",
            type: :offense,
            regex: nil,
            cost: { spirit: 0, mana: 1 },
            cost_type: :invoked,
            duration: 10 * Char.level,
            cooldown_duration: nil,
            summary: "Increases Attack Strength by +5 for 10 seconds/level (#{10 * Char.level}).",
            spell_number: 9904,
          },
          "sign_of_clotting"     => {
            rank: 5,
            short_name: "clotting",
            type: :utility,
            regex: nil,
            cost: { spirit: 0, mana: 1 },
            cost_type: :invoked,
            duration: 10 * Char.level,
            cooldown_duration: nil,
            summary: "Stops bleeding immediately for 10 seconds/level (#{10 * Char.level}).",
            spell_number: 9905,
          },
          "sign_of_thought"      => {
            rank: 6,
            short_name: "thought",
            type: :utility,
            regex: nil,
            cost: { spirit: 0, mana: 1 },
            cost_type: :invoked,
            duration: 600 + (6 * Char.level),
            cooldown_duration: nil,
            summary: "Gives the same effect as rubbing a crystal amulet for 10 minutes + 6 seconds/level (#{600 + (6 * Char.level)}).",
            spell_number: 9906,
          },
          "sign_of_defending"    => {
            rank: 7,
            short_name: "defending",
            type: :defense,
            regex: nil,
            cost: { spirit: 0, mana: 2 },
            cost_type: :invoked,
            duration: 10 * Char.level,
            cooldown_duration: nil,
            summary: "Increases Defensive Strength by +10 for 10 seconds/level (#{10 * Char.level}).",
            spell_number: 9907,
          },
          "sign_of_smiting"      => {
            rank: 8,
            short_name: "smiting",
            type: :offense,
            regex: nil,
            cost: { spirit: 0, mana: 2 },
            cost_type: :invoked,
            duration: 10 * Char.level,
            cooldown_duration: nil,
            summary: "Increases Attack Strength by +10 for 10 seconds/level (#{10 * Char.level}).",
            spell_number: 9908,
          },
          "sign_of_staunching"   => {
            rank: 9,
            short_name: "staunching",
            type: :utility,
            regex: nil,
            cost: { spirit: 0, mana: 1 },
            cost_type: :invoked,
            duration: 20 * Char.level,
            cooldown_duration: nil,
            summary: "Stops all bleeding for 20 seconds/level (#{20 * Char.level}).",
            spell_number: 9909,
          },
          "sign_of_deflection"   => {
            rank: 10,
            short_name: "deflection",
            type: :defense,
            regex: nil,
            cost: { spirit: 0, mana: 3 },
            cost_type: :invoked,
            duration: 10 * Char.level,
            cooldown_duration: nil,
            summary: "Increases Bolt DS by +20 for 10 seconds/level (#{10 * Char.level}).",
            spell_number: 9910,
          },
          "sign_of_hypnosis"     => {
            rank: 11,
            short_name: "hypnosis",
            type: :utility,
            regex: nil,
            cost: { spirit: 1, mana: 0 },
            cost_type: :invoked,
            duration: nil,
            cooldown_duration: nil,
            summary: "Calms a random target with a hidden warding check for a variable duration.",
            spell_number: 9911,
          },
          "sign_of_swords"       => {
            rank: 12,
            short_name: "swords",
            type: :offense,
            regex: nil,
            cost: { spirit: 1, mana: 0 },
            cost_type: :dissipates,
            duration: 10 * Char.level,
            cooldown_duration: nil,
            summary: "Increases Attack Strength by +20 for 10 seconds/level (#{10 * Char.level}).",
            spell_number: 9912,
          },
          "sign_of_shields"      => {
            rank: 13,
            short_name: "shields",
            type: :defense,
            regex: nil,
            cost: { spirit: 1, mana: 0 },
            cost_type: :dissipates,
            duration: 10 * Char.level,
            cooldown_duration: nil,
            summary: "Increases Defensive Strength by +20 for 10 seconds/level (#{10 * Char.level}).",
            spell_number: 9913,
          },
          "sign_of_dissipation"  => {
            rank: 14,
            short_name: "dissipation",
            type: :defense,
            regex: nil,
            cost: { spirit: 1, mana: 0 },
            cost_type: :dissipates,
            duration: 10 * Char.level,
            cooldown_duration: nil,
            summary: "Increases Target Defense by +15 for 10 seconds/level (#{10 * Char.level}).",
            spell_number: 9914,
          },
          "sign_of_healing"      => {
            rank: 15,
            short_name: "healing",
            type: :utility,
            regex: nil,
            cost: { spirit: 2, mana: 0 },
            cost_type: :invoked,
            duration: nil,
            cooldown_duration: nil,
            summary: "Fully regenerates all hit points.",
            spell_number: 9915,
          },
          "sign_of_madness"      => {
            rank: 16,
            short_name: "madness",
            type: :utility,
            regex: nil,
            cost: { spirit: 3, mana: 0 },
            cost_type: :dissipates,
            duration: 15,
            cooldown_duration: nil,
            summary: "+50 to AS, -50 to DS for 15 seconds.",
            spell_number: 9916,
          },
          "sign_of_possession"   => {
            rank: 17,
            short_name: "possession",
            type: :utility,
            regex: nil,
            cost: { spirit: 4, mana: 0 },
            cost_type: :invoked,
            duration: nil,
            cooldown_duration: nil,
            summary: "Mass Calm the room with a hidden warding roll.",
            spell_number: 9917,
          },
          "sign_of_wracking"     => {
            rank: 18,
            short_name: "wracking",
            type: :utility,
            regex: nil,
            cost: { spirit: 5, mana: 0 },
            cost_type: :invoked,
            duration: nil,
            cooldown_duration: nil,
            summary: "Instantly replenishes all mana.",
            spell_number: 9918,
          },
          "sign_of_darkness"     => {
            rank: 19,
            short_name: "darkness",
            type: :utility,
            regex: nil,
            cost: { spirit: 6, mana: 0 },
            cost_type: :invoked,
            duration: nil,
            cooldown_duration: nil,
            summary: "Teleports the user to a \"safe point\" or to the nearest Council chapter (whichever is closer).	",
            spell_number: 9919,
          },
          "sign_of_hopelessness" => {
            rank: 20,
            short_name: "hopelessness",
            type: :utility,
            regex: nil,
            cost: { spirit: 0, mana: 0 },
            cost_type: nil,
            duration: nil,
            cooldown_duration: nil,
            summary: "Causes you to decay while dead.",
            spell_number: 9920,
          },
        }

        ##
        # Retrieves a sign definition by short name.
        #
        # @param short_name [String]
        # @return [Hash, nil]
        #
        def self.[](short_name)
          normalized = Lich::Utils.normalize_name(short_name)
          @@col_signs.values.find { |sigil| sigil[:short_name] == normalized }
        end

        ##
        # Returns true if the character knows the sign (based on Society.rank)
        #
        # @param sign_name [String]
        # @return [Boolean]
        #
        def self.known?(sign_name)
          normalized = Lich::Utils.normalize_name(sign_name)
          @@col_signs[normalized][:rank] <= self.rank
        end

        ##
        # Attempts to use a Council of Light sign by issuing the appropriate game command.
        #
        # If a custom `:usage` value is defined for the sign, it is used as the command;
        # otherwise, defaults to `sign of <short_name>`. If the sign is not available
        # (i.e., not known or not affordable), an error is raised.
        #
        # @param sign_name [String] The name (long or short) of the sign to invoke.
        # @param target [String, nil] Optional target to append to the command.
        # @raise [RuntimeError] If the sign is not known or cannot be used at this time.
        # @return [void]
        #
        def self.use(sign_name, target = nil)
          normalized_name = Lich::Utils.normalize_name(sign_name)
          if self.available?(normalized_name)
            if @@col_signs[normalized_name][:usage]
              fput "#{@@col_signs[normalized_name][:usage]} #{target}".strip
            else
              fput "sign of #{@@col_signs[normalized_name][:short_name]} #{target}".strip
            end
          else
            raise "You cannot use the #{sign_name} sign right now."
          end
        end

        ##
        # Determines if the character has enough spirit and mana to use a given sign.
        #
        # @param sign_name [String]
        # @return [Boolean]
        #
        def self.affordable?(sign_name)
          normalized = Lich::Utils.normalize_name(sign_name)
          cost = @@col_signs[normalized][:cost]
          return true unless cost

          # Need to account for Swords/Shields/Dissipation/Madness costs that come at the END of their usage
          # so we check the pending_spirit_loss and ensure that the total spirit cost
          # does not exceed the character's current available spirit.

          (cost[:spirit] || 0) + pending_spirit_loss < Char.spirit &&
            (cost[:mana] || 0) <= Char.mana
        end

        ##
        # Calculates the total pending spirit loss from active Council of Light signs
        # that consume spirit when their effects end (i.e., cost_type is :dissipates).
        #
        # Only signs with a non-zero :spirit cost and active buff status are considered.
        # Mana costs are ignored.
        #
        # @return [Integer] Total spirit points that will be lost when applicable signs expire.
        #
        def self.pending_spirit_loss
          @@col_signs.values
                     .select { |sign| sign[:cost_type] == :dissipates }
                     .select { |sign| Effects::Buffs.active?("Sign of #{sign[:short_name].capitalize}") }
                     .sum { |sign| sign.dig(:cost, :spirit).to_i }
        end

        ##
        # Determines if a sign is both known and affordable.
        #
        # Signs with a `:cost_type` of `:dissipates` will return `false` if they are currently active
        # in `Effects::Buffs`, as their spirit cost is paid upon expiration, and re-use is not allowed.
        #
        # @param sign_name [String] The long or short name of the sign.
        # @return [Boolean] True if the sign is usable right now.
        #
        def self.available?(sign_name)
          normalized = Lich::Utils.normalize_name(sign_name)
          sign = @@col_signs[normalized]

          return false unless sign
          return false unless self.known?(normalized) && self.affordable?(normalized)

          if sign[:cost_type] == :dissipates
            return false if Effects::Buffs.active?("Sign of #{sign[:short_name].capitalize}")
          end

          true
        end

        ##
        # Returns an array of all CoL sign data, including costs.
        #
        def self.sign_lookups
          @@col_signs.map do |long_name, sign|
            {
              long_name: long_name,
              short_name: sign[:short_name],
              rank: sign[:rank],
              cost: sign[:cost]
            }
          end
        end

        # Dynamically define method accessors
        CouncilOfLight.sign_lookups.each do |sign|
          define_singleton_method(sign[:short_name]) { CouncilOfLight[sign[:short_name]] }
          define_singleton_method(sign[:long_name])  { CouncilOfLight[sign[:short_name]] }
        end
      end
    end
  end
end
