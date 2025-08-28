module Lich
  module Gemstone
    module Societies
      ##
      # Represents the Guardians of Sunfist society.
      #
      # Provides access to Guardians of Sunfist sigil data, cost calculation, usability checks,
      # and dynamic method access for individual sigils.
      #
      class GuardiansOfSunfist < Gemstone::Society
        ##
        # Metadata for each Sigil from the Guardians of Sunfist, including rank, costs, duration, etc.
        # Some fields (e.g., `:summary`, `:duration`) may be defined as lambdas for dynamic content.
        # These are automatically resolved at access time via `Society.resolve`.
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
            summary: -> { "Increases Climbing, Swimming, and Survival skills equal to half current rank (#{(Society.rank / 2).floor}) for 90 seconds." }
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
            summary: "Allows you to perform actions with bandaged wounds that would normally break them for 5 minutes."
          },
          "sigil_of_defense"          => {
            rank: 7,
            short_name: "defense",
            long_name: "Sigil of Defense",
            spell_number: 9707,
            cost: { stamina: 5, mana: 5 },
            duration: 300,
            summary: -> { "Increases +1 DS per rank (#{Society.rank}) for 5 minutes." }
          },
          "sigil_of_offense"          => {
            rank: 8,
            short_name: "offense",
            long_name: "Sigil of Offense",
            spell_number: 9708,
            cost: { stamina: 5, mana: 5 },
            duration: 300,
            summary: -> { "Increases +1 AS per rank (#{Society.rank}) for 5 minutes." }
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
            summary: -> { "Increases +1 TD per rank (#{Society.rank}) for 1 minute. Can be stacked up to 3 minutes." }
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
            summary: -> { "Instantly recover 15 HP or half of your lost HP, whichever is greater (right now: #{[((Char.max_health - Char.health) / 2), 15].max})." }
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
        }.freeze

        ##
        # Retrieves a sigil definition by short or long name.
        #
        # Normalizes the provided name and attempts to match against both short and long names
        # of all Guardians of Sunfist sigils. Returns the corresponding sigil metadata if found.
        #
        # @param name [String] The short or long name of the sigil
        # @return [Hash, nil] The sigil metadata, or nil if not found
        #
        def self.[](name)
          lookup = Society.lookup(name, sigil_lookups)
          return nil unless lookup

          key = lookup[:short_name]
          sigil = @@sunfist_sigils.values.find { |entry| entry[:short_name] == key }
          return nil unless sigil

          sigil.transform_values do |v|
            if v.respond_to?(:call)
              v.arity == 1 ? v.call(sigil) : v.call
            else
              v
            end
          end
        end

        ##
        # Returns a simplified list of all sigils with key attributes used for lookup and UI.
        #
        # Used internally to normalize and match against sigil names.
        #
        # @return [Array<Hash>] Each hash contains:
        #   - :short_name [String]
        #   - :long_name [String]
        #   - :rank [Integer]
        #   - :cost [Hash]
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
        # Determines if the character knows a given Sunfist sigil, based on society rank.
        #
        # Uses the unified `[]` method for normalized lookup by short or long name.
        #
        # @param sigil_name [String] The short or long name of the sigil
        # @return [Boolean] True if the character's rank is sufficient to use the sigil
        #
        def self.known?(sigil_name)
          return false unless member?
          sigil = self[sigil_name]
          return false unless sigil

          sigil[:rank] <= self.rank
        end

        ##
        # Attempts to use a Guardians of Sunfist sigil by issuing the appropriate command.
        #
        # If the sigil has a defined `:usage` string, it is used directly.
        # Otherwise, defaults to `sigil of <short_name>`.
        #
        # @param sigil_name [String] The short or long name of the sigil to invoke
        # @param target [String, nil] Optional target for the sigil (appended to command)
        # @return [void]
        #
        def self.use(sigil_name, target = nil)
          unless member?
            Lich::Messaging.msg("error", "Not a member of Guardians of Sunfist, can't use: #{sigil_name}")
            return
          end
          sigil = self[sigil_name]

          unless sigil
            Lich::Messaging.msg("error", "Unknown sigil: #{sigil_name}")
            return
          end

          if available?(sigil_name)
            command = sigil[:usage] || "sigil of #{sigil[:short_name]}"
            waitrt?
            waitcastrt?
            fput "#{command} #{target}".strip
          else
            Lich::Messaging.msg("warn", "You cannot use the #{sigil_name} sigil right now.")
          end
        end

        ##
        # Checks if the character can currently afford to use a given Guardians of Sunfist sigil,
        # based on available stamina and mana.
        #
        # @param sigil_name [String] Long or short name of the sigil
        # @return [Boolean] True if the sigil can be afforded now
        #
        def self.affordable?(sigil_name)
          return false unless member?
          sigil = self[sigil_name]
          return false unless sigil

          cost = sigil[:cost] || {}
          stamina_cost = cost[:stamina].to_i
          mana_cost = cost[:mana].to_i

          unless stamina_cost.zero?
            return false unless Char.stamina >= stamina_cost
          end

          unless mana_cost.zero?
            return false unless Char.mana >= mana_cost
          end

          return true
        end

        ##
        # Determines whether the specified Guardians of Sunfist sigil is currently available for use.
        #
        # A sigil is considered available if:
        # - The character knows the sigil (based on rank)
        # - The character can afford the sigil (based on stamina and mana)
        #
        # @param sigil_name [String] Long or short name of the sigil
        # @return [Boolean] True if the sigil can be used right now
        #
        def self.available?(sigil_name)
          return false unless member?
          known?(sigil_name) && affordable?(sigil_name)
        end

        ##
        # Returns all Guardians of Sunfist sigil metadata entries with evaluated fields.
        #
        # @return [Array<Hash>] An array of sigil metadata hashes with lambdas resolved
        #
        def self.all
          @@sunfist_sigils.values.map { |entry| entry.transform_values { |v| Society.resolve(v, entry) } }
        end

        ##
        # Checks if the character is a member of the Guardians of Sunfist,
        # and optionally at a specific rank.
        #
        # @param rank [Integer, nil] Optional specific rank to check against
        # @return [Boolean] True if the character is a Sunfist member (and at the specified rank, if given)
        #
        def self.member?(rank = nil)
          return false unless Society.membership == "Guardians of Sunfist"
          rank.nil? || Society.rank == rank
        end

        ##
        # Checks if the character is a Sunfist master (rank 20).
        #
        # @return [Boolean] True if the character has achieved master rank in the Guardians of Sunfist
        #
        def self.master?
          return false unless member?
          Society.rank == 20
        end

        ##
        # Provides the current rank of the character within the Guardians of Sunfist.
        #
        # @return [Integer] The current rank of the character
        #
        def self.rank
          return 0 unless member?
          Society.rank
        end

        ##
        # Dynamically defines singleton methods for each Guardians of Sunfist sigil.
        #
        # Each method allows accessing the sigil's metadata by calling either its
        # short name or long name as a method. For example:
        #
        #   GuardiansOfSunfist.resolve        #=> metadata for Sigil of Resolve
        #   GuardiansOfSunfist["Sigil of Resolve"] #=> same result
        #
        define_name_methods(self, @@sunfist_sigils)
      end
    end
  end
end
