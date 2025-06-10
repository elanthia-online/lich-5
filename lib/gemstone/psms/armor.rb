# The root namespace for Lich scripting extensions.
module Lich
  # Namespace for Gemstone IV-specific modules and helpers.
  module Gemstone
    # Provides logic for detecting, checking, and using PSM3 armor techniques in GemStone IV.
    #
    # This module defines a registry of available armor-related abilities and wraps common queries
    # like whether a technique is known, affordable, or currently usable. It also provides the
    # `use` method to execute the appropriate command in-game, handling roundtime and feedback matching.
    #
    # Techniques are stored in a constant hash, and dynamic methods are defined for both long and short
    # names of each technique.
    #
    # Example:
    #   if Armor.available?("armor_blessing")
    #     Armor.use("armor_blessing")
    #   end
    module Armor
      # Mapping of armor technique identifiers to their associated data, including:
      # - short name
      # - usage command
      # - regex to match expected in-game output
      # - cost to use
      # - type of technique (buff, passive, etc.)
      #
      # @return [Hash<String, Hash>] A lookup table of armor techniques
      @@armor_techniques = {
        "armor_blessing"      => {
          :short_name => "blessing",
          :type       => :buff,
          :cost       => { stamina: 0 },
          :regex      => /As \w+ prays? over \w+(?:'s)? [\w\s]+, you sense that (?:the Arkati's|a) blessing will be granted against magical attacks\./i,
          :usage      => "blessing"
        },
        "armor_reinforcement" => {
          :short_name => "reinforcement",
          :type       => :buff,
          :cost       => { stamina: 0 },
          :regex      => /\w+ adjusts? \w+(?:'s)? [\w\s]+, reinforcing weak spots\./i,
          :usage      => "reinforcement"
        },
        "armor_spike_mastery" => {
          :short_name => "spikemastery",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Armor Spike Mastery is passive and always active once learned\./i,
          :usage      => "spikemastery"
        },
        "armor_support"       => {
          :short_name => "support",
          :type       => :buff,
          :cost       => { stamina: 0 },
          :regex      => /\w+ adjusts? \w+(?:'s)? [\w\s]+, improving its ability to support the weight of \w+ gear\./i,
          :usage      => "support"
        },
        "armored_casting"     => {
          :short_name => "casting",
          :type       => :buff,
          :cost       => { stamina: 0 },
          :regex      => /\w+ adjusts? \w+(?:'s)? [\w\s]+, making it easier for \w+ to recover from failed spell casting\./i,
          :usage      => "casting"
        },
        "armored_evasion"     => {
          :short_name => "evasion",
          :type       => :buff,
          :cost       => { stamina: 0 },
          :regex      => /\w+ adjusts? \w+(?:'s)? [\w\s]+, improving its comfort and maneuverability\./i,
          :usage      => "evasion"
        },
        "armored_fluidity"    => {
          :short_name => "fluidity",
          :type       => :buff,
          :cost       => { stamina: 0 },
          :regex      => /\w+ adjusts? \w+(?:'s)? [\w\s]+, making it easier for \w+ to cast spells\./i,
          :usage      => "fluidity"
        },
        "armored_stealth"     => {
          :short_name => "stealth",
          :type       => :buff,
          :cost       => { stamina: 0 },
          :regex      => /\w+ adjusts? \w+(?:'s)? [\w\s]+ to cushion \w+ movements\./i,
          :usage      => "stealth"
        },
        "crush_protection"    => {
          :short_name => "crush",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => Regexp.union(
            /You adjust \w+(?:'s)? [\w\s]+ with your (?:cloth|leather|scale|chain|plate|accessory) armor fittings, rearranging and reinforcing the armor to better protect against crushing damage\./i,
            /You must specify an armor slot\./,
            /You don't seem to have the necessary armor fittings in hand\./
          ),
          :usage      => "crush"
        },
        "puncture_protection" => {
          :short_name => "puncture",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => Regexp.union(
            /You adjust \w+(?:'s)? [\w\s]+ with your (?:cloth|leather|scale|chain|plate|accessory) armor fittings, rearranging and reinforcing the armor to better protect against puncturing damage\./i,
            /You must specify an armor slot\./,
            /You don't seem to have the necessary armor fittings in hand\./
          ),
          :usage      => "puncture"
        },
        "slash_protection"    => {
          :short_name => "slash",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => Regexp.union(
            /You adjust \w+(?:'s)? [\w\s]+ with your (?:cloth|leather|scale|chain|plate|accessory) armor fittings, rearranging and reinforcing the armor to better protect against slashing damage\./i,
            /You must specify an armor slot\./,
            /You don't seem to have the necessary armor fittings in hand\./
          ),
          :usage      => "slash"
        }
      }

      # Returns a simplified array, for lookup purposes, of armor technique hashes with
      # long name, short name, and cost.
      #
      # @return [Array<Hash>] An array of hashes with keys :long_name, :short_name, and :cost
      def self.armor_lookups
        @@armor_techniques.map do |long_name, psm|
          {
            long_name: long_name,
            short_name: psm[:short_name],
            cost: psm[:cost]
          }
        end
      end

      # Looks up the rank known of an armor technique.
      #
      # @param name [String] The name of the armor technique
      # @return [Integer] The rank of the technique, or 0 if unknown
      # @example
      #   Armor["armor_blessing"] => 2
      #   Armor["armor_blessing"] => 0 # if not known
      def Armor.[](name)
        return PSMS.assess(name, 'Armor')
      end

      # Determines if the character knows an armor technique at all, and
      # optionally if the character knows it at the specified rank.
      #
      # @param name [String] The name of the armor technique
      # @param min_rank [Integer] Optionally, the minimum rank to test against (default: 1, so known)
      # @return [Boolean] True if the technique is known at or above the given rank
      # @example
      #   Armor.known?("armor_blessing") => true # if any number of ranks is known
      #   Armor.known?("armor_blessing", min_rank: 2) => false # if only rank 1 is known
      def Armor.known?(name, min_rank: 1)
        min_rank = 1 unless min_rank >= 1 # in case a 0 or below is passed
        Armor[name] >= min_rank
      end

      # Determines if an armor technique is affordable, and optionally tests
      # affordability with a given number of FORCERTs having been used (including the current one).
      #
      # @param name [String] The name of the armor technique
      # @param forcert_count [Integer] Optionally, the count of FORCERTs being used, including for this execution (default: 0)
      # @return [Boolean] True if the technique can be used with available FORCERTs
      # @example
      #   Armor.affordable?("armor_blessing") => true # if enough skill and stamina
      #   Armor.affordable?("armor_blessing", forcert_count: 1) => false  # if not enough skill or stamina
      def Armor.affordable?(name, forcert_count: 0)
        return PSMS.assess(name, 'Armor', true, forcert_count: forcert_count)
      end

      # Determines if an armor technique is available to use right now by testing:
      # - if the technique is known
      # - if the technique is affordable
      # - if the technique is not on cooldown
      # - if the character is not overexerted
      # - if the character is capable of performing the number of FORCERTs specified
      #
      # @param name [String] The name of the armor technique
      # @param min_rank [Integer] Optionally, the minimum rank to check (default: 1)
      # @param forcert_count [Integer] Optionally, the count of FORCERTs being used (default: 0)
      # @return [Boolean] True if the technique is known, affordable, and not on cooldown or
      # blocked by overexertion
      # @example
      #   Armor.available?("armor_blessing") => true # if known, affordable, not on cooldown, and not overexerted
      def Armor.available?(name, min_rank: 1, forcert_count: 0)
        Armor.known?(name, min_rank: min_rank) &&
          Armor.affordable?(name, forcert_count: forcert_count) &&
          PSMS.available?(name)
      end

      # Checks whether the technique's buff is currently active.
      #
      # @param name [String] The technique's name
      # @return [Boolean] True if buff is already active
      def Armor.buff_active?(name)
        return unless @@armor_techniques.fetch(PSMS.find_name(name, "Armor")[:long_name]).key?(:buff)
        Effects::Buffs.active?(@@armor_techniques.fetch(PSMS.find_name(name, "Armor")[:long_name])[:buff])
      end

      # Attempts to use an armor technique, optionally on a target.
      #
      # @param name [String] The name of the armor technique
      # @param target [String, Integer, GameObj] The target of the technique (optional). If unspecified, the technique will be used on the character.
      # @param results_of_interest [Regexp, nil] Additional regex to capture from result (optional)
      # @param forcert_count [Integer] Number of FORCERTs to use (default: 0)
      # @return [String, nil] The result of the regex match, or nil if unavailable
      # @example
      #   Armor.use("armor_blessing") # attempt to use armor blessing on self
      #   Armor.use("armor_blessing", "Dissonance") # attempt to use armor blessing on Dissonance
      def Armor.use(name, target = "", results_of_interest: nil, forcert_count: 0)
        return unless Armor.available?(name, forcert_count: forcert_count)

        name_normalized = PSMS.name_normal(name)
        technique = @@armor_techniques.fetch(PSMS.find_name(name_normalized, "Armor")[:long_name])
        usage = technique[:usage]
        return if usage.nil?

        in_cooldown_regex = /^#{name} is still in cooldown\./i

        results_regex = Regexp.union(
          PSMS::FAILURES_REGEXES,
          /^#{name} what\?$/i,
          in_cooldown_regex,
          technique[:regex],
          /^Roundtime: [0-9]+ sec\.$/,
          /^\w+ [a-z]+ not wearing any armor that you can work with\.$/
        )

        results_regex = Regexp.union(results_regex, results_of_interest) if results_of_interest.is_a?(Regexp)

        usage_cmd = "armor #{usage}"
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

        usage_result = dothistimeout usage_cmd, 5, results_regex
        if usage_result == "You don't seem to be able to move to do that."
          100.times { break if clear.any? { |line| line =~ /^You regain control of your senses!$/ }; sleep 0.1 }
          usage_result = dothistimeout usage_cmd, 5, results_regex
        end
        usage_result
      end

      # Returns the "success" regex associated with a given armor technique name.
      # This regex is used to match the expected output when the technique is successfully *attempted*.
      # It does not necessarily indicate that the technique was successful in its effect, or even
      # that the technique was executed at all.
      #
      # @param name [String] The technique name
      # @return [Regexp] The regex used to match technique success or effects
      # @example
      #   Armor.regexp("armor_blessing") => /As \w+ prays? over \w+(?:'s)? [\w\s]+, you sense that (?:the Arkati's|a) blessing will be granted against magical attacks\./i
      def Armor.regexp(name)
        @@armor_techniques.fetch(PSMS.find_name(name, "Armor")[:long_name])[:regex]
      end

      # Defines dynamic getter methods for both long and short names of each armor technique.
      #
      # @note This block dynamically defines methods like `Armor.blessing` and `Armor.armor_blessing`
      # @example
      #   Armor.blessing # returns the rank of armor_blessing based on the short name
      #   Armor.armor_blessing # returns the rank of armor_blessing based on the long name
      Armor.armor_lookups.each { |armor|
        self.define_singleton_method(armor[:short_name]) do
          Armor[armor[:short_name]]
        end

        self.define_singleton_method(armor[:long_name]) do
          Armor[armor[:short_name]]
        end
      }
    end
  end
end
