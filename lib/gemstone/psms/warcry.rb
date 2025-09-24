# The root namespace for Lich scripting components.
module Lich
  # GemStone IV-specific modules and extensions.
  module Gemstone
    # Class for managing and using Warcries in GemStone IV.
    #
    # Warcries are cost-based vocal abilities that provide buffs or perform effects. This class provides:
    # - Metadata for each known warcry (cost, regex, optional buff name)
    # - Checks for knowledge, affordability, cooldown, and buff activity
    # - Execution logic including FORCERT handling
    #
    # Dynamic singleton methods are created for each warcry by long and short name.
    class Warcry
      # Internal table of all warcry abilities.
      #
      # @return [Hash<String, Hash>] Mapping from long name to metadata, including:
      #   - `:long_name` [String]
      #   - `:short_name` [String]
      #   - `:cost` [Integer]
      #   - `:regex` [Regexp]
      #   - `:buff` [String, optional]
      @@warcries = {
        "bertrandts_bellow" => {
          :long_name  => "bertrandts_bellow",
          :short_name => "bellow",
          :type       => :setup,
          :cost       => { stamina: 20 }, # @todo only 10 for single
          :regex      => /You glare at .+ and let out a nerve-shattering bellow!/,
        },
        "yerties_yowlp"     => {
          :long_name  => "yerties_yowlp",
          :short_name => "yowlp",
          :type       => :buff,
          :cost       => { stamina: 20 },
          :regex      => /You throw back your shoulders and let out a resounding yowlp!/,
          :buff       => "Yertie's Yowlp",
        },
        "gerrelles_growl"   => {
          :long_name  => "gerrelles_growl",
          :short_name => "growl",
          :type       => :setup,
          :cost       => { stamina: 14 }, # @todo only 7 for single
          :regex      => /Your face contorts as you unleash a guttural, deep-throated growl at .+!/,
        },
        "seanettes_shout"   => {
          :long_name  => "seanettes_shout",
          :short_name => "shout",
          :type       => :buff,
          :cost       => { stamina: 20 },
          :regex      => /You let loose an echoing shout!/,
          :buff       => 'Empowered (+20)',
        },
        "carns_cry"         => {
          :long_name  => "carns_cry",
          :short_name => "cry",
          :type       => :setup,
          :cost       => { stamina: 20 },
          :regex      => /You stare down .+ and let out an eerie, modulating cry!/,
        },
        "horlands_holler"   => {
          :long_name  => "horlands_holler",
          :short_name => "holler",
          :type       => :buff,
          :cost       => { stamina: 20 },
          :regex      => /You throw back your head and let out a thundering holler!/,
          :buff       => 'Enh. Health (+20)',
        },
      }

      # Returns a summary array of all warcries, including long name, short name, and cost.
      #
      # @return [Array<Hash>] Each hash has :long_name, :short_name, :cost
      def self.warcry_lookups
        @@warcries.map do |long_name, psm|
          {
            long_name: long_name,
            short_name: psm[:short_name],
            cost: psm[:cost]
          }
        end
      end

      # Looks up the rank known of a warcry.  In reality, warcries are not ranked, but this is a
      # convenient way to check if a warcry is known or not that fits with the rest of the PSMS.
      #
      # @param name [String] The name of the warcry
      # @return [Integer] The rank of the warcry, or 0 if unknown
      # @example
      #   Warcry["holler"] => 1 # if known
      #   Warcry["holler"] => 0 # if not known
      def Warcry.[](name)
        return PSMS.assess(name, 'Warcry')
      end

      # Determines if the character knows a warcry at all, and
      # optionally if the character knows it at the specified rank.
      # In reality, warcries are not ranked, but this is a
      # convenient way to check if a warcry is known or not that fits
      # with the rest of the PSMS.
      #
      # @param name [String] The name of the warcry
      # @param min_rank [Integer] Optionally, the minimum rank to test against (default: 1, so known)
      # @return [Boolean] True if the technique is known at or above the given rank
      # @example
      #   Warcry.known?("holler") => true # if any number of ranks is known
      def Warcry.known?(name, min_rank: 1)
        min_rank = 1 unless min_rank >= 1 # in case a 0 or below is passed
        Warcry[name] >= min_rank
      end

      # Determines if a warcry is affordable, and optionally tests
      # affordability with a given number of FORCERTs having been used (including the current one).
      #
      # @param name [String] The name of the warcry
      # @param forcert_count [Integer] Optionally, the count of FORCERTs being used, including for this execution (default: 0)
      # @return [Boolean] True if the technique can be used with available FORCERTs
      # @example
      #   Warcry.affordable?("holler") => true # if enough skill and stamina
      #   Warcry.affordable?("holler", forcert_count: 1) => false  # if not enough skill or stamina
      def Warcry.affordable?(name, forcert_count: 0)
        return PSMS.assess(name, 'Warcry', true, forcert_count: forcert_count)
      end

      # Determines if a warcry is available to use right now by testing:
      # - if the technique is known
      # - if the technique is affordable
      # - if the technique is not on cooldown
      # - if the character is not overexerted
      # - if the character is capable of performing the number of FORCERTs specified
      #
      # @param name [String] The name of the warcry
      # @param min_rank [Integer] Optionally, the minimum rank to check (default: 1)
      # @param forcert_count [Integer] Optionally, the count of FORCERTs being used (default: 0)
      # @return [Boolean] True if the technique is known, affordable, and not on cooldown or
      # blocked by overexertion
      # @example
      #   Warcry.available?("holler") => true # if known, affordable, not on cooldown, and not overexerted
      def Warcry.available?(name, min_rank: 1, forcert_count: 0)
        Warcry.known?(name, min_rank: min_rank) &&
          Warcry.affordable?(name, forcert_count: forcert_count) &&
          PSMS.available?(name)
      end

      # DEPRECATED: Use {#buff_active?} instead.
      # Checks whether the warcry's buff is currently active.
      #
      # @param name [String] Warcry name
      # @return [Boolean] True if buff is already active
      def Warcry.buffActive?(name)
        ### DEPRECATED ###
        Lich.deprecated("Warcry.buffActive?", "Warcry.buff_active?", caller[0], fe_log: false)
        buff_active?(name)
      end

      # Checks whether the warcry's buff is currently active.
      #
      # @param name [String] Warcry name
      # @return [Boolean] True if buff is already active
      def Warcry.buff_active?(name)
        buff = @@warcries.fetch(PSMS.find_name(name, "Warcry")[:long_name])[:buff]
        return false if buff.nil?
        Lich::Util.normalize_lookup('Buffs', buff)
      end

      # Attempts to use a warcry, optionally on a target.
      #
      # @param name [String] The name of the warcry
      # @param target [String, Integer, GameObj] The target of the technique (optional). If unspecified, the target is assumed to be the user.
      # @param results_of_interest [Regexp, nil] Additional regex to capture from result (optional)
      # @param forcert_count [Integer] Number of FORCERTs to use (default: 0)
      # @return [String, nil] The result of the regex match, or nil if unavailable
      # @example
      #   Warcry.use("holler") # attempt to use holler on self
      #   Warcry.use("holler", "Dissonance") # attempt to use holler on Dissonance
      def Warcry.use(name, target = "", results_of_interest: nil, forcert_count: 0)
        return unless Warcry.available?(name, forcert_count: forcert_count)
        return if Warcry.buff_active?(name)

        name_normalized = PSMS.name_normal(name)
        technique = @@warcries.fetch(PSMS.find_name(name_normalized, "Warcry")[:long_name])
        usage = name_normalized
        return if usage.nil?

        in_cooldown_regex = /^#{name} is still in cooldown\./i

        results_regex = Regexp.union(
          PSMS::FAILURES_REGEXES,
          /^#{name} what\?$/i,
          in_cooldown_regex,
          technique[:regex],
          /^Roundtime: [0-9]+ sec\.$/,
        )

        results_regex = Regexp.union(results_regex, results_of_interest) if results_of_interest.is_a?(Regexp)

        usage_cmd = "warcry #{usage}"
        if target.is_a?(GameObj)
          usage_cmd += " ##{target.id}"
        elsif target.is_a?(Integer)
          usage_cmd += " ##{target}"
        elsif target != ""
          usage_cmd += " #{target}"
        end

        if forcert_count > 0
          usage_cmd += " forcert"
        else # if we're using forcert, we don't want to wait for rt, but we need to otherwise
          waitrt?
          waitcastrt?
        end

        usage_result = dothistimeout(usage_cmd, 5, results_regex)
        if usage_result == "You don't seem to be able to move to do that."
          100.times { break if clear.any? { |line| line =~ /^You regain control of your senses!$/ }; sleep 0.1 }
          usage_result = dothistimeout(usage_cmd, 5, results_regex)
        end
        usage_result
      end

      # Returns the "success" regex associated with a given warcry name.
      # This regex is used to match the expected output when the technique is successfully *attempted*.
      # It does not necessarily indicate that the technique was successful in its effect, or even
      # that the technique was executed at all.
      #
      # @param name [String] The technique name
      # @return [Regexp] The regex used to match technique success or effects
      # @example
      #   Warcry.regexp("holler") => /As \w+ prays? over \w+(?:'s)? [\w\s]+, you sense that (?:the Arkati's|a) blessing will be granted against magical attacks\./i
      def Warcry.regexp(name)
        @@warcries.fetch(PSMS.find_name(name, "Warcry")[:long_name])[:regex]
      end

      # Defines dynamic getter methods for both long and short names of each warcry.
      #
      # @note This block dynamically defines methods like `Warcry.holler` and `Warcry.bertrandts_bellow`
      # @example
      #   Warcry.holler # returns the rank of holler based on the short name
      Warcry.warcry_lookups.each { |warcry|
        self.define_singleton_method(warcry[:short_name]) do
          Warcry[warcry[:short_name]]
        end

        self.define_singleton_method(warcry[:long_name]) do
          Warcry[warcry[:short_name]]
        end
      }
    end
  end
end
