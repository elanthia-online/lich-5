# The root module for Lich scripting.
module Lich
  # GemStone IV-specific extensions for Lich.
  module Gemstone
    # Provides access to Feats learned by a character in GemStone IV.
    #
    # This module supports checking feat knowledge, availability, and cost (including FORCERT use),
    # as well as triggering their usage. Each feat is described in a metadata hash which includes:
    # - long and short names
    # - cost
    # - expected in-game output (regex)
    # - optional usage string for execution
    #
    # Dynamic accessor methods are created for each feat's long and short name.
    module Feat
      # A registry of all known feats and their properties.
      #
      # @return [Hash<String, Hash>] A mapping of feat names to metadata including:
      #   - `:short_name` [String]
      #   - `:type` [String, nil]
      #   - `:cost` [Integer]
      #   - `:regex` [Regexp] for expected output
      #   - `:usage` [String, nil] command usage
      @@feats = {
        "absorb_magic"              => {
          :short_name => "absorbmagic",
          :type       => :buff,
          :cost       => { stamina: 0 },
          :regex      => Regexp.union(/You open yourself to the ravenous void at the core of your being, allowing it to surface\.  Muted veins of metallic grey ripple just beneath your skin\./,
                                      /You strain, but the void within remains stubbornly out of reach\.  You need more time\./),
          :usage      => "absorbmagic"
        },
        "chain_armor_proficiency"   => {
          :short_name => "chainarmor",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Chain Armor Proficiency is passive and cannot be activated\./,
          :usage      => nil
        },
        "chastise"                  => {
          :short_name => "chastise",
          :type       => :attack,
          :cost       => { stamina: 10 },
          :regex      => /as you lunge at .+? in a quick and vicious strike!$/,
          :usage      => "chastise"
        },
        "combat_mastery"            => {
          :short_name => "combatmastery",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Combat Mastery is passive and cannot be activated\./,
          :usage      => nil
        },
        "covert_art_escape_artist"  => {
          :short_name => "escapeartist",
          :type       => :reaction,
          :cost       => { stamina: 0 },
          :regex      => Regexp.union(/You roll your shoulders and subtly test the flexion of your joints, staying limber for ready escapes\./,
                                      /You were unable to find any targets that meet Covert Art\: Escape Artist's reaction requirements\./),
          :usage      => "escapeartist"
        },
        "covert_art_keen_eye"       => {
          :short_name => "keeneye",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Covert Art\: Keen Eye is always active as long as you stay up to date on training\./,
          :usage      => nil
        },
        "covert_art_poisoncraft"    => {
          :short_name => "poisoncraft",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /USAGE\: FEAT POISONCRAFT \{options\} \[args\]/,
          :usage      => nil
        },
        "covert_art_sidestep"       => {
          :short_name => "sidestep",
          :type       => :buff,
          :cost       => { stamina: 10 },
          :regex      => /You tread lightly and keep your head on a swivel, prepared to sidestep any loose salvos that might stray your way\./,
          :usage      => "sidestep"
        },
        "covert_art_swift_recovery" => {
          :short_name => "swiftrecovery",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Covert Art\: Swift Recovery is always active as long as you stay up to date on training\./,
          :usage      => nil
        },
        "covert_art_throw_poison"   => {
          :short_name => "throwpoison",
          :type       => :attack,
          :cost       => { stamina: 15 },
          :regex      => Regexp.union(/What did the .+ ever do to you\?/,
                                      /You pop the cork on .+ and, with a nimble flick of the wrist, fling a portion of its contents in a wide arc\!/,
                                      /Covert Art\: Throw Poison what\?/),
          :usage      => "throwpoison"
        },
        "covert_arts"               => {
          :short_name => "covert",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /USAGE\: FEAT COVERT \{options\} \[args\]/,
          :usage      => nil
        },
        "critical_counter"          => {
          :short_name => "criticalcounter",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Critical Counter is passive and cannot be activated\./,
          :usage      => nil
        },
        "dispel_magic"              => {
          :short_name => "dispelmagic",
          :type       => :buff,
          :cost       => { stamina: 30 },
          :regex      => Regexp.union(/You reach for the emptiness within, but there are no spells afflicting you to dispel\./,
                                      /You reach for the emptiness within\.  A single, hollow note reverberates through your core, resonating outward and scouring away the energies that cling to you\./),
          :usage      => "dispelmagic"
        },
        "dragonscale_skin"          => {
          :short_name => "dragonscaleskin",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /The Dragonscale Skin\s{1,2}feat is always active once you have learned it\./,
          :usage      => nil
        },
        "excoriate"                 => {
          :short_name => "excoriate",
          :type       => :attack,
          :cost       => { mana: 10 },
          :regex      => /You level your .+? at .+? and call down the excoriating power of .+? to smite (?:him|her|it)!/,
          :usage      => "excoriate"
        },
        "guard"                     => {
          :short_name => "guard",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => Regexp.union(/Guard what\?/,
                                      /You move over to .+ and prepare to guard [a-z]+ from attack\./,
                                      /You stop guarding .+, move over to .+, and prepare to guard [a-z]+ from attack\./,
                                      /You stop protecting .+, move over to .+, and prepare to guard [a-z]+ from attack\./,
                                      /You stop protecting .+ and prepare to guard [a-z]+ instead\./,
                                      /You are already guarding .+\./),
          :usage      => "guard"
        },
        "kroderine_soul"            => {
          :short_name => "kroderinesoul",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Kroderine Soul is passive and always active as long as you do not learn any spells\.  You have access to two new abilities\:/,
          :usage      => nil
        },
        "light_armor_proficiency"   => {
          :short_name => "lightarmor",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Light Armor Proficiency is passive and cannot be activated\./,
          :usage      => nil
        },
        "martial_arts_mastery"      => {
          :short_name => "martialarts",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Martial Arts Mastery is passive and cannot be activated\./,
          :usage      => nil
        },
        "martial_mastery"           => {
          :short_name => "martialmastery",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Martial Mastery is passive and cannot be activated\./,
          :usage      => nil
        },
        "mental_acuity"             => {
          :short_name => "mentalacuity",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /The Mental Acuity\s{1,2}feat is always active once you have learned it\./,
          :usage      => nil
        },
        "mystic_strike"             => {
          :short_name => "mysticstrike",
          :type       => :buff,
          :cost       => { stamina: 10 },
          :regex      => /You prepare yourself to deliver a Mystic Strike with your next attack\./,
          :usage      => "mysticstrike"
        },
        "mystic_tattoo"             => {
          :short_name => "tattoo",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Usage\:/,
          :usage      => nil
        },
        "perfect_self"              => {
          :short_name => "perfectself",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /The Perfect Self feat is always active once you have learned it\.  It provides a constant enhancive bonus to all your stats\./,
          :usage      => nil
        },
        "plate_armor_proficiency"   => {
          :short_name => "platearmor",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Plate Armor Proficiency is passive and cannot be activated\./,
          :usage      => nil
        },
        "protect"                   => {
          :short_name => "protect",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => Regexp.union(/Protect what\?/,
                                      /You move over to .+ and prepare to protect [a-z]+ from attack\./,
                                      /You stop protecting .+, move over to .+, and prepare to protect [a-z]+ from attack\./,
                                      /You stop guarding .+, move over to .+, and prepare to protect [a-z]+ from attack\./,
                                      /You stop guarding .+ and prepare to protect [a-z]+ instead\./,
                                      /You are already protecting .+\./),
          :usage      => "protect"
        },
        "scale_armor_proficiency"   => {
          :short_name => "scalearmor",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /Scale Armor Proficiency is passive and cannot be activated\./,
          :usage      => nil
        },
        "shadow_dance"              => {
          :short_name => "shadowdance",
          :type       => :buff,
          :cost       => { stamina: 30 },
          :regex      => /You focus your mind and body on the shadows\./,
          :usage      => nil
        },
        "silent_strike"             => {
          :short_name => "silentstrike",
          :type       => :attack,
          :cost       => { stamina: 20 },
          :regex      => Regexp.union(/Silent Strike can not be used with fire as the attack type\./,
                                      /You quickly leap from hiding to attack\!/),
          :usage      => "silentstrike"
        },
        "vanish"                    => {
          :short_name => "vanish",
          :type       => :buff,
          :cost       => { stamina: 30 },
          :regex      => /With subtlety and speed, you aim to clandestinely vanish into the shadows\./,
          :usage      => "vanish"
        },
        "weapon_bonding"            => {
          :short_name => "weaponbonding",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /USAGE\:/,
          :usage      => nil
        },
        "weighting"                 => {
          :short_name => "wps",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /USAGE\: FEAT WPS \{options\} \[args\]/,
          :usage      => nil
        },
        "padding"                   => {
          :short_name => "wps",
          :type       => :passive,
          :cost       => { stamina: 0 },
          :regex      => /USAGE\: FEAT WPS \{options\} \[args\]/,
          :usage      => nil
        }
      }

      # Returns a simplified list of feat metadata.
      #
      # @return [Array<Hash>] Each hash includes :long_name, :short_name, and :cost
      def self.feat_lookups
        @@feats.map do |long_name, psm|
          {
            long_name: long_name,
            short_name: psm[:short_name],
            cost: psm[:cost]
          }
        end
      end

      # Looks up the rank known of a feat.
      #
      # @param name [String] The name of the feat
      # @return [Integer] The rank of the technique, or 0 if unknown
      # @example
      #   Feat["covert_art_escape_artist"] => 1 # if known
      #   Feat["covert_art_escape_artist"] => 0 # if not known
      def Feat.[](name)
        return PSMS.assess(name, 'Feat')
      end

      # Determines if the character knows a feat at all, and
      # optionally if the character knows it at the specified rank.
      #
      # @param name [String] The name of the feat
      # @param min_rank [Integer] Optionally, the minimum rank to test against (default: 1, so known)
      # @return [Boolean] True if the feat is known at or above the given rank
      # @example
      #   Feat.known?("covert_art_escape_artist") => true # if any number of ranks is known
      #   Feat.known?("covert_art_escape_artist", min_rank: 2) => false # if only rank 1 is known
      def Feat.known?(name, min_rank: 1)
        min_rank = 1 unless min_rank >= 1 # in case a 0 or below is passed
        Feat[name] >= min_rank
      end

      # Determines if an Feat is affordable, and optionally tests
      # affordability with a given number of FORCERTs having been used (including the current one).
      #
      # @param name [String] The name of the Feat
      # @param forcert_count [Integer] Optionally, the count of FORCERTs being used, including for this execution (default: 0)
      # @return [Boolean] True if the feat can be used with available FORCERTs
      # @example
      #   Feat.affordable?("covert_art_escape_artist") => true # if enough skill and stamina
      #   Feat.affordable?("covert_art_escape_artist", forcert_count: 1) => false  # if not enough skill or stamina
      def Feat.affordable?(name, forcert_count: 0)
        return PSMS.assess(name, 'Feat', true, forcert_count: forcert_count)
      end

      # Determines if an Feat is available to use right now by testing:
      # - if the feat is known
      # - if the feat is affordable
      # - if the feat is not on cooldown
      # - if the character is not overexerted
      # - if the character is capable of performing the number of FORCERTs specified
      #
      # @param name [String] The name of the Feat technique
      # @param min_rank [Integer] Optionally, the minimum rank to check (default: 1)
      # @param forcert_count [Integer] Optionally, the count of FORCERTs being used (default: 0)
      # @return [Boolean] True if the technique is known, affordable, and not on cooldown or
      # blocked by overexertion
      # @example
      #   Feat.available?("covert_art_escape_artist") => true # if known, affordable, not on cooldown, and not overexerted
      def Feat.available?(name, min_rank: 1, forcert_count: 0)
        Feat.known?(name, min_rank: min_rank) &&
          Feat.affordable?(name, forcert_count: forcert_count) &&
          PSMS.available?(name)
      end

      # Checks whether the feat's buff is currently active.
      #
      # @param name [String] The feat's name
      # @return [Boolean] True if buff is already active
      def Feat.buff_active?(name)
        return unless @@feats.fetch(PSMS.find_name(name, "Feat")[:long_name]).key?(:buff)
        Effects::Buffs.active?(@@feats.fetch(PSMS.find_name(name, "Feat")[:long_name])[:buff])
      end

      # Attempts to use an Feat, optionally on a target.
      #
      # @param name [String] The name of the Feat
      # @param target [String, Integer, GameObj] The target of the feat (optional).  If unspecified, the technique will be used on the character.
      # @param results_of_interest [Regexp, nil] Additional regex to capture from result (optional)
      # @param forcert_count [Integer] Number of FORCERTs to use (default: 0)
      # @return [String, nil] The result of the regex match, or nil if unavailable
      # @example
      #   Feat.use("covert_art_escape_artist") # attempt to use the feat on self
      #   Feat.use("covert_art_escape_artist", "Dissonance") # attempt to use Feat blessing on Dissonance
      def Feat.use(name, target = "", results_of_interest: nil, forcert_count: 0)
        return unless Feat.available?(name, forcert_count: forcert_count)

        name_normalized = PSMS.name_normal(name)
        technique = @@feats.fetch(PSMS.find_name(name_normalized, "Feat")[:long_name])
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

        usage_cmd = (['guard', 'protect'].include?(usage) ? "#{usage}" : "feat #{usage}")
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

      # Returns the "success" regex associated with a given Feat technique name.
      # This regex is used to match the expected output when the technique is successfully *attempted*.
      # It does not necessarily indicate that the technique was successful in its effect, or even
      # that the technique was executed at all.
      #
      # @param name [String] The technique name
      # @return [Regexp] The regex used to match technique success or effects
      # @example
      #   Feat.regexp("covert_art_escape_artist") => /As \w+ prays? over \w+(?:'s)? [\w\s]+, you sense that (?:the Arkati's|a) blessing will be granted against magical attacks\./i
      def Feat.regexp(name)
        @@feats.fetch(PSMS.find_name(name, "Feat")[:long_name])[:regex]
      end

      # Defines dynamic getter methods for both long and short names of each Feat technique.
      #
      # @note This block dynamically defines methods like `Feat.blessing` and `Feat.covert_art_escape_artist`
      # @example
      #   Feat.blessing # returns the rank of covert_art_escape_artist based on the short name
      #   Feat.covert_art_escape_artist # returns the rank of covert_art_escape_artist based on the long name
      Feat.feat_lookups.each { |feat|
        self.define_singleton_method(feat[:short_name]) do
          Feat[feat[:short_name]]
        end

        self.define_singleton_method(feat[:long_name]) do
          Feat[feat[:short_name]]
        end
      }
    end
  end
end
