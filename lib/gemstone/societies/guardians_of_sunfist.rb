module Lich
  module Gemstone
    module Society
      ##
      # Represents the Guardians of Sunfist society.
      #
      # Provides access to Guardians of Sunfist sigil data, cost calculation, usability checks,
      # and dynamic method access for individual sigils.
      #
      class GuardiansOfSunfist < Society
        ##
        # Metadata for each Sigil from the Guardians of Sunfist, including rank, costs, duration, etc.
        #
        # @return [Hash<String, Hash>] Sigil name mapped to metadata
        #
        @@sunfist_sigils = {
          "sigil_of_recognition"      => {
            rank: 1,
            short_name: "recognition",
            long_name: "Sigil of Recognition",
            type: :utility,
            spell_number: 9701,
            cost: { stamina: 0, mana: 0 },
            duration: nil,
            summary: "Detects members and/or foes of the Guardians of Sunfist in the same room."
          },
          "sigil_of_location"         => {
            rank: 2,
            short_name: "location",
            long_name: "Sigil of Location",
            spell_number: 9702,
            cost: { stamina: 0, mana: 0 },
            duration: nil,
            summary: "Detects nearby foes and warcamps; reveals paths to them."
          },
          "sigil_of_contact"          => {
            rank: 3,
            short_name: "contact",
            long_name: "Sigil of Contact",
            spell_number: 9703,
            cost: { stamina: 0, mana: 1 },
            duration: 1140, # 19 minutes
            summary: "Activates the ESP (amunet) network."
          },
          "sigil_of_resolve"          => {
            rank: 4,
            short_name: "resolve",
            long_name: "Sigil of Resolve",
            spell_number: 9704,
            cost: { stamina: 5, mana: 0 },
            duration: 90,
            summary: "Increases Climbing, Swimming, and Survival skills for 90 seconds equal to half current rank (#{(Society.rank / 2).floor} for 90 seconds)."
          },
          "sigil_of_minor_bane"       => {
            rank: 5,
            short_name: "minor bane",
            long_name: "Sigil of Minor Bane",
            spell_number: 9705,
            cost: { stamina: 3, mana: 3 },
            duration: 60,
            summary: "Adds +5 AS (for any target) and grants heavy damage weighting (against foes) to melee, ranged and bolt attacks for 60 seconds."
          },
          "sigil_of_bandages"         => {
            rank: 6,
            short_name: "bandages",
            long_name: "Sigil of Bandages",
            spell_number: 9706,
            cost: { stamina: 10, mana: 0 },
            duration: 300,
            summary: "Allows you to performe actions with bandaged wounds that would normally break them for 5 minutes."
          },
          "sigil_of_defense"          => {
            rank: 7,
            short_name: "defense",
            long_name: "Sigil of Defense",
            spell_number: 9707,
            cost: { stamina: 5, mana: 5 },
            duration: 300,
            summary: "Increases +1 DS per rank (#{Society.rank}) for 5 minutes."
          },
          "sigil_of_offense"          => {
            rank: 8,
            short_name: "offense",
            long_name: "Sigil of Offense",
            spell_number: 9708,
            cost: { stamina: 5, mana: 5 },
            duration: 300,
            summary: "Increases +1 AS per rank (#{Society.rank}) for 5 minutes."
          },
          "sigil_of_distraction"      => {
            rank: 9,
            short_name: "distraction",
            long_name: "Sigil of Distraction",
            spell_number: 9709,
            cost: { stamina: 10, mana: 5 },  ## TODO: Figure out how to calc room version cost instead
            duration: nil,
            summary: "Decreases enemies' chances to evade, parry, and block."
          },
          "sigil_of_minor_protection" => {
            rank: 10,
            short_name: "minor protection",
            long_name: "Sigil of Minor Protection",
            spell_number: 9710,
            cost: { stamina: 10, mana: 5 },
            duration: 60,
            summary: "Adds +5 DS and grants heavy damage padding for 1 minute. Can be stacked up to 3 minutes."
          },
          "sigil_of_focus"            => {
            rank: 11,
            short_name: "focus",
            long_name: "Sigil of Focus",
            spell_number: 9711,
            cost: { stamina: 5, mana: 5 },
            duration: 60,
            summary: "Increases +1 TD per rank (#{Society.rank}) for 1 minute. Can be stacked up to 3 minutes."
          },
          "sigil_of_intimidation"     => {
            rank: 12,
            short_name: "intimidation",
            long_name: "Sigil of Intimidation",
            spell_number: 9712,
            cost: { stamina: 10, mana: 5 },
            duration: nil,
            summary: "Decreases enemies' AS/DS by 20."
          },
          "sigil_of_mending"          => {
            rank: 13,
            short_name: "mending",
            long_name: "Sigil of Mending",
            spell_number: 9713,
            cost: { stamina: 15, mana: 10 },
            duration: 600,
            summary: "Increases HP recovery by 15 and allows all healing herbs to be eaten in 3 seconds for 10 minutes."
          },
          "sigil_of_concentration"    => {
            rank: 14,
            short_name: "concentration",
            long_name: "Sigil of Concentration",
            spell_number: 9714,
            cost: { stamina: 30, mana: 0 },
            duration: 600,
            summary: "Increases mana recovery by +5 mana per pulse for 10 minutes."
          },
          "sigil_of_major_bane"       => {
            rank: 15,
            short_name: "major bane",
            long_name: "Sigil of Major Bane",
            spell_number: 9715,
            cost: { stamina: 10, mana: 10 },
            duration: 60,
            summary: "Adds +10 AS (all attacks) and grants heavy crit weighting to attacks (against foes) for 1 minute."
          },
          "sigil_of_determination"    => {
            rank: 16,
            short_name: "determination",
            long_name: "Sigil of Determination",
            spell_number: 9716,
            cost: { stamina: 30, mana: 0 },
            duration: 300,
            summary: "Ignores penalties while performing tasks when a character has injuries for 5 minutes."
          },
          "sigil_of_health"           => {
            rank: 17,
            short_name: "health",
            long_name: "Sigil of Health",
            spell_number: 9717,
            cost: { stamina: 20, mana: 10 },
            duration: nil,
            summary: "Instantly recover 15 HP or half of your lost HP, whichever is greater (right now: #{[((Char.max_hp - Char.hp) / 2), 15].max})."
          },
          "sigil_of_power"            => {
            rank: 18,
            short_name: "power",
            long_name: "Sigil of Power",
            spell_number: 9718,
            cost: { stamina: 50, mana: 0 },
            duration: nil,
            summary: "Convert 50 stamina to 25 mana."
          },
          "sigil_of_major_protection" => {
            rank: 19,
            short_name: "major protection",
            long_name: "Sigil of Major Protection",
            spell_number: 9719,
            cost: { stamina: 15, mana: 10 },
            duration: 60,
            summary: "Adds +10 DS and grants heavy crit padding for 1 minute. Can be stacked up to 3 minutes."
          },
          "sigil_of_escape"           => {
            rank: 20,
            short_name: "escape",
            long_name: "Sigil of Escape",
            spell_number: 9720,
            cost: { stamina: 75, mana: 15 }, ## TODO: figure out higher cost?
            duration: nil,
            summary: "Teleports you to a safe location. The emergency version can be used while stunned, bound, in RT, etc., at higher cost."
          }
        }

        ##
        # Retrieves a sigil definition by its short name.
        #
        # @param short_name [String] The short name of the sigil
        # @return [Hash, nil] The sigil metadata, or nil if not found
        #
        def self.[](short_name)
          normalized_name = Lich::Utils.normalize_name(short_name)
          @@sunfist_sigils.values.find { |sigil| sigil[:short_name] == normalized_name }
        end

        ##
        # Returns a summary of sigil lookups including rank and costs.
        #
        # @return [Array<Hash>] An array of sigil metadata with costs
        #
        def self.sigil_lookups
          @@sunfist_sigils.map do |_, sigil|
            {
              long_name: sigil[:long_name],
              short_name: sigil[:short_name],
              rank: sigil[:rank],
              cost: sigil[:cost],
            }
          end
        end

        ##
        # Determines if the character knows a given sigil based on their rank.
        #
        # @param sigil_name [String] The long name of the sigil
        # @return [Boolean] True if the sigil is known (rank unlocked)
        #
        def self.known?(sigil_name)
          normalized_name = Lich::Utils.normalize_name(sigil_name)
          sigil = @@sunfist_sigils[normalized_name]
          return false unless sigil

          sigil[:rank] <= self.rank
        end

        ##
        # Attempts to use a sigil by issuing the `sigil of <name>` command.
        #
        # @param sigil_name [String] The sigil to invoke
        # @raise [RuntimeError] If the sigil is not available
        #
        def self.use(sigil_name, target = nil)
          normalized_name = Lich::Utils.normalize_name(sigil_name)
          sigil = @@sunfist_sigils[normalized_name]
          raise "Sigil not found: #{sigil_name}" unless sigil

          if self.available?(normalized_name)
            fput "sigil of #{sigil[:short_name]} #{target}".strip
          else
            raise "You cannot use the #{sigil_name} sigil right now."
          end
        end

        ##
        # Checks if the character has enough resources to use a given sigil.
        #
        # @param sigil_name [String] The sigil's long name
        # @return [Boolean] True if the character has enough resources
        #
        def self.affordable?(sigil_name)
          normalized_name = Lich::Utils.normalize_name(sigil_name)
          sigil = @@sunfist_sigils[normalized_name]
          return false unless sigil

          Char.stamina >= sigil[:stamina_cost] && Char.mana >= sigil[:mana_cost]
        end

        ##
        # Determines if a sigil is both known and affordable.
        #
        # @param sigil_name [String] The sigil's long name
        # @return [Boolean] True if the sigil is usable
        #
        def self.available?(sigil_name)
          normalized_name = Lich::Utils.normalize_name(sigil_name)
          self.known?(normalized_name) && self.affordable?(normalized_name)
        end

        ##
        # Checks if the character is a member of Sunfist and optionally at a given rank.
        #
        # @param rank [Integer, nil] Optionally check if the character is at this rank
        # @return [Boolean] True if the character is a Sunfist member (and at the specified rank, if given)
        #
        def self.member?(rank = nil)
          return false unless Society.member_of == "Guardians of Sunfist"
          rank.nil? || Society.rank == rank
        end

        # Dynamically define accessors for each sigil using its long and short names
        GuardiansOfSunfist.sigil_lookups.each do |sigil|
          define_singleton_method(sigil[:short_name]) do
            GuardiansOfSunfist[sigil[:short_name]]
          end

          define_singleton_method(sigil[:long_name]) do
            GuardiansOfSunfist[sigil[:short_name]]
          end
        end
      end
    end
  end
end
