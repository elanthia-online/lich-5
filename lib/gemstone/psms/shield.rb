# The root namespace for all Lich scripting components.
module Lich
  # Namespace for GemStone IV-specific modules.
  module Gemstone
    # Provides logic for shield-based PSM techniques in GemStone IV.
    #
    # This module defines metadata for each known shield technique, including passive and active skills,
    # usage commands, costs, and expected success message regexes. It offers methods for checking whether
    # a technique is known, affordable, or currently available, and for attempting to use a technique.
    #
    # Dynamic shortcut methods are also defined for each shield technique using both long and short names.
    module Shield
      # Internal registry of all shield techniques and their metadata.
      #
      # @return [Hash<String, Hash>] Each key is a long name and maps to:
      #   - `:short_name` [String] shorthand reference
      #   - `:type` [String, nil] type of skill (e.g., passive, stance)
      #   - `:cost` [Integer] stamina cost
      #   - `:regex` [Regexp] expected in-game output
      #   - `:usage` [String, nil] usage string if applicable
      @@shield_techniques = {
        "adamantine_bulwark"    => {
          :short_name => "bulwark",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Adamantine Bulwark does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "block_specialization"  => {
          :short_name => "blockspec",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /The Block Specialization combat maneuver is always active once you have learned it\./,
          :usage      => nil
        },
        "block_the_elements"    => {
          :short_name => "blockelements",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Block the Elements does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "deflect_magic"         => {
          :short_name => "deflectmagic",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Deflect Magic does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage      => nil
        },
        "deflect_missiles"      => {
          :short_name => "deflectmissiles",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Deflect Missiles does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage      => nil
        },
        "deflect_the_elements"  => {
          :short_name => "deflectelements",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Deflect the Elements does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "disarming_presence"    => {
          :short_name => "dpresence",
          :type       => :martial_stance,
          :cost       => { stamina: 20 },
          :regex      => Regexp.union(/You assume the Disarming Presence Stance, adjusting your footing and grip to allow for the proper pivot and thrust technique to disarm attacking foes\./,
                                      /You re\-settle into the Disarming Presence Stance, re-ensuring your footing and grip are properly positioned\./),
          :usage      => "dpresence"
        },
        "guard_mastery"         => {
          :short_name => "gmastery",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Guard Mastery does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "large_shield_focus"    => {
          :short_name => "lfocus",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Large Shield Focus does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "medium_shield_focus"   => {
          :short_name => "mfocus",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Medium Shield Focus does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "phalanx"               => {
          :short_name => "phalanx",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Phalanx does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "prop_up"               => {
          :short_name => "prop",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Prop Up does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage      => nil
        },
        "protective_wall"       => {
          :short_name => "pwall",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Protective Wall does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "shield_bash"           => {
          :short_name => "bash",
          :type       => :setup,
          :cost       => { stamina: 9 },
          :regex      => /You lunge forward at .+ with your .+ and attempt a shield bash\!/,
          :usage      => "bash"
        },
        "shield_charge"         => {
          :short_name => "charge",
          :type       => :setup,
          :cost       => { stamina: 14 },
          :regex      => /You charge forward at .+ with your .+ and attempt a shield charge\!/,
          :usage      => "charge"
        },
        "shield_forward"        => {
          :short_name => "forward",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Shield Forward does not need to be activated once you have learned it\.  It will automatically activate upon the use of a shield attack\./,
          :usage      => "forward"
        },
        "shield_mind"           => {
          :short_name => "mind",
          :type       => :buff,
          :cost       => { stamina: 10 },
          :regex      => /You must be wielding an ensorcelled or anti-magical shield to be able to properly shield your mind and soul\./,
          :usage      => "mind"
        },
        "shield_pin"            => {
          :short_name => "pin",
          :type       => :attack,
          :cost       => { stamina: 15 },
          :regex      => /You attempt to expose a vulnerability with a diversionary shield bash on .+\!/,
          :usage      => "pin"
        },
        "shield_push"           => {
          :short_name => "push",
          :type       => :setup,
          :cost       => { stamina: 7 },
          :regex      => /You raise your .+ before you and attempt to push .+ away\!/,
          :usage      => "push"
        },
        "shield_riposte"        => {
          :short_name => "riposte",
          :type       => :martial_stance,
          :cost       => { stamina: 20 },
          :regex      => Regexp.union(/You assume the Shield Riposte Stance, preparing yourself to lash out at a moment's notice\./,
                                      /You re\-settle into the Shield Riposte Stance, preparing yourself to lash out at a moment's notice\./),
          :usage      => "riposte"
        },
        "shield_spike_mastery"  => {
          :short_name => "spikemastery",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Shield Spike Mastery does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "shield_strike"         => {
          :short_name => "strike",
          :type       => :attack,
          :cost       => { stamina: 15 },
          :regex      => /You launch a quick bash with your .+ at .+\!/,
          :usage      => "strike"
        },
        "shield_strike_mastery" => {
          :short_name => "strikemastery",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Shield Strike Mastery does not need to be activated once you have learned it\.  It will automatically apply to all relevant focused multi\-attacks, provided that you maintain the prerequisite ranks of Shield Bash\./,
          :usage      => nil
        },
        "shield_swiftness"      => {
          :short_name => "swiftness",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Shield Swiftness does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a small or medium shield and have at least 3 ranks of the relevant Shield Focus specialization\./,
          :usage      => nil
        },
        "shield_throw"          => {
          :short_name => "throw",
          :type       => :area_of_effect,
          :cost       => { stamina: 20 },
          :regex      => /You snap your arm forward, hurling your .+ at .+ with all your might\!/,
          :usage      => "throw"
        },
        "shield_trample"        => {
          :short_name => "trample",
          :type       => :area_of_effect,
          :cost       => { stamina: 14 },
          :regex      => /You raise your .+ before you and charge headlong towards .+\!/,
          :usage      => "trample"
        },
        "shielded_brawler"      => {
          :short_name => "brawler",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Shielded Brawler does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage      => nil
        },
        "small_shield_focus"    => {
          :short_name => "sfocus",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Small Shield Focus does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil
        },
        "spell_block"           => {
          :short_name => "spellblock",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Spell Block does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage      => nil
        },
        "steady_shield"         => {
          :short_name => "steady",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Steady Shield does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks against you, provided that you maintain the prerequisite ranks of Stun Maneuvers\./,
          :usage      => nil
        },
        "steely_resolve"        => {
          :short_name => "resolve",
          :type       => :buff,
          :cost       => { stamina: 30 },
          :regex      => Regexp.union(/You focus your mind in a steely resolve to block all attacks against you\./,
                                      /You are still mentally fatigued from your last invocation of your Steely Resolve\./),
          :usage      => "resolve"
        },
        "tortoise_stance"       => {
          :short_name => "tortoise",
          :type       => :martial_stance,
          :cost       => { stamina: 20 },
          :regex      => Regexp.union(/You assume the Stance of the Tortoise, holding back some of your offensive power in order to maximize your defense\./,
                                      /You re\-settle into the Stance of the Tortoise, holding back your offensive power in order to maximize your defense\./),
          :usage      => "tortoise"
        },
        "tower_shield_focus"    => {
          :short_name => "tfocus",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Tower Shield Focus does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./i,
          :usage      => nil
        }
      }

      # Returns an array of simplified technique metadata.
      #
      # @return [Array<Hash>] Each contains :long_name, :short_name, and :cost
      def self.shield_lookups
        @@shield_techniques.map do |long_name, psm|
          {
            long_name: long_name,
            short_name: psm[:short_name],
            cost: psm[:cost]
          }
        end
      end

      # Looks up the rank known of a shield technique.
      #
      # @param name [String] The name of the shield technique
      # @return [Integer] The rank of the technique, or 0 if unknown
      # @example
      #   Feat["shield_trample"] => 2
      #   Feat["shield_trample"] => 0 # if not known
      def Shield.[](name)
        return PSMS.assess(name, 'Shield')
      end

      # Determines if the character knows a shield technique at all, and
      # optionally if the character knows it at the specified rank.
      #
      # @param name [String] The name of the shield technique
      # @param min_rank [Integer] Optionally, the minimum rank to test against (default: 1, so known)
      # @return [Boolean] True if the technique is known at or above the given rank
      # @example
      #   Shield.known?("shield_trample") => true # if any number of ranks is known
      #   Shield.known?("shield_trample", min_rank: 2) => false # if only rank 1 is known
      def Shield.known?(name, min_rank: 1)
        min_rank = 1 unless min_rank >= 1 # in case a 0 or below is passed
        Shield[name] >= min_rank
      end

      # Determines if an Shield technique is affordable, and optionally tests
      # affordability with a given number of FORCERTs having been used (including the current one).
      #
      # @param name [String] The name of the Shield technique
      # @param forcert_count [Integer] Optionally, the count of FORCERTs being used, including for this execution (default: 0)
      # @return [Boolean] True if the technique can be used with available FORCERTs
      # @example
      #   Shield.affordable?("shield_trample") => true # if enough skill and stamina
      #   Shield.affordable?("shield_trample", forcert_count: 1) => false  # if not enough skill or stamina
      def Shield.affordable?(name, forcert_count: 0)
        return true if @@shield_techniques.fetch(PSMS.find_name(name, "Shield")[:long_name])[:type] == :area_of_effect && Effects::Buffs.active?("Glorious Momentum")
        return PSMS.assess(name, 'Shield', true, forcert_count: forcert_count)
      end

      # Determines if a Shield technique is available to use right now by testing:
      # - if the technique is known
      # - if the technique is affordable
      # - if the technique is not on cooldown
      # - if the character is not overexerted
      # - if the character is capable of performing the number of FORCERTs specified
      #
      # @param name [String] The name of the Shield technique
      # @param min_rank [Integer] Optionally, the minimum rank to check (default: 1)
      # @param forcert_count [Integer] Optionally, the count of FORCERTs being used (default: 0)
      # @return [Boolean] True if the technique is known, affordable, and not on cooldown or
      # blocked by overexertion
      # @example
      #   Shield.available?("shield_trample") => true # if known, affordable, not on cooldown, and not overexerted
      def Shield.available?(name, min_rank: 1, forcert_count: 0)
        Shield.known?(name, min_rank: min_rank) &&
          Shield.affordable?(name, forcert_count: forcert_count) &&
          PSMS.available?(name)
      end

      # Checks whether the technique's buff is currently active.
      #
      # @param name [String] The technique's name
      # @return [Boolean] True if buff is already active
      def Shield.buff_active?(name)
        return unless @@shield_techniques.fetch(PSMS.find_name(name, "Shield")[:long_name]).key?(:buff)
        Effects::Buffs.active?(@@shield_techniques.fetch(PSMS.find_name(name, "Shield")[:long_name])[:buff])
      end

      # Attempts to use an Shield technique, optionally on a target.
      #
      # @param name [String] The name of the Shield technique
      # @param target [String, Integer, GameObj] The target of the technique (optional).  If unspecified, the technique will be used on the character.
      # @param results_of_interest [Regexp, nil] Additional regex to capture from result (optional)
      # @param forcert_count [Integer] Number of FORCERTs to use (default: 0)
      # @return [String, nil] The result of the regex match, or nil if unavailable
      # @example
      #   Shield.use("shield_trample") # attempt to use Shield blessing on self
      #   Shield.use("shield_trample", "Dissonance") # attempt to use Shield blessing on Dissonance
      def Shield.use(name, target = "", results_of_interest: nil, forcert_count: 0)
        return unless Shield.available?(name, forcert_count: forcert_count)

        name_normalized = PSMS.name_normal(name)
        technique = @@shield_techniques.fetch(PSMS.find_name(name_normalized, "Shield")[:long_name])
        usage = technique[:usage]
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

        usage_cmd = "shield #{usage}"
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

      # Returns the "success" regex associated with a given Shield technique name.
      # This regex is used to match the expected output when the technique is successfully *attempted*.
      # It does not necessarily indicate that the technique was successful in its effect, or even
      # that the technique was executed at all.
      #
      # @param name [String] The technique name
      # @return [Regexp] The regex used to match technique success or effects
      # @example
      #   Shield.regexp("shield_trample") => /As \w+ prays? over \w+(?:'s)? [\w\s]+, you sense that (?:the Arkati's|a) blessing will be granted against magical attacks\./i
      def Shield.regexp(name)
        @@shield_techniques.fetch(PSMS.find_name(name, "Shield")[:long_name])[:regex]
      end

      # Defines dynamic getter methods for both long and short names of each Shield technique.
      #
      # @note This block dynamically defines methods like `Shield.blessing` and `Shield.shield_trample`
      # @example
      #   Shield.blessing # returns the rank of shield_trample based on the short name
      #   Shield.shield_trample # returns the rank of shield_trample based on the long name
      Shield.shield_lookups.each { |shield|
        self.define_singleton_method(shield[:short_name]) do
          Shield[shield[:short_name]]
        end

        self.define_singleton_method(shield[:long_name]) do
          Shield[shield[:short_name]]
        end
      }
    end
  end
end
