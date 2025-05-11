## breakout for Shield released with PSM3
## new code for 5.0.16
## includes new functions .known? and .affordable?
module Lich
  module Gemstone
    module Shield
      @@shield_techniques = {
        "adamantine_bulwark"    => {
          :cost       => 0,
          :regex      => /Adamantine Bulwark does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil,
          :short_name => 'bulwark'
        },
        "block_specialization"  => {
          :cost       => 0,
          :type       => "passive",
          :regex      => /The Block Specialization combat maneuver is always active once you have learned it\./,
          :usage      => nil,
          :short_name => 'blockspec'
        },
        "block_the_elements"    => {
          :cost       => 0,
          :regex      => /Block the Elements does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil,
          :short_name => 'blockelements'
        },
        "deflect_magic"         => {
          :cost       => 0,
          :regex      => /Deflect Magic does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage      => nil,
          :short_name => 'deflectmagic'
        },
        "deflect_missiles"      => {
          :cost       => 0,
          :regex      => /Deflect Missiles does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage      => nil,
          :short_name => 'deflectmissiles'
        },
        "deflect_the_elements"  => {
          :cost       => 0,
          :regex      => /Deflect the Elements does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil,
          :short_name => 'deflectelements'
        },
        "disarming_presence"    => {
          :cost       => 20,
          :regex      => Regexp.union(/You assume the Disarming Presence Stance, adjusting your footing and grip to allow for the proper pivot and thrust technique to disarm attacking foes\./,
                                      /You re\-settle into the Disarming Presence Stance, re-ensuring your footing and grip are properly positioned\./),
          :usage      => "dpresence",
          :short_name => 'dpresence'
        },
        "guard_mastery"         => {
          :cost       => 0,
          :regex      => /Guard Mastery does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil,
          :short_name => 'gmastery'
        },
        "large_shield_focus"    => {
          :cost       => 0,
          :regex      => /Large Shield Focus does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil,
          :short_name => 'lfocus'
        },
        "medium_shield_focus"   => {
          :cost       => 0,
          :regex      => /Medium Shield Focus does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil,
          :short_name => 'mfocus'
        },
        "phalanx"               => {
          :cost       => 0,
          :regex      => /Phalanx does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil,
          :short_name => 'phalanx'
        },
        "prop_up"               => {
          :cost       => 0,
          :regex      => /Prop Up does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage      => nil,
          :short_name => 'prop'
        },
        "protective_wall"       => {
          :cost       => 0,
          :regex      => /Protective Wall does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil,
          :short_name => 'pwall'
        },
        "shield_bash"           => {
          :cost       => 9,
          :regex      => /You lunge forward at .+ with your .+ and attempt a shield bash\!/,
          :usage      => "bash",
          :short_name => 'bash'
        },
        "shield_charge"         => {
          :cost       => 14,
          :regex      => /You charge forward at .+ with your .+ and attempt a shield charge\!/,
          :usage      => "charge",
          :short_name => 'charge'
        },
        "shield_forward"        => {
          :cost       => 0,
          :regex      => /Shield Forward does not need to be activated once you have learned it\.  It will automatically activate upon the use of a shield attack\./,
          :usage      => "forward",
          :short_name => 'forward'
        },
        "shield_mind"           => {
          :cost       => 10,
          :regex      => /You must be wielding an ensorcelled or anti-magical shield to be able to properly shield your mind and soul\./,
          :usage      => "mind",
          :short_name => 'mind'
        },
        "shield_pin"            => {
          :cost       => 15,
          :regex      => /You attempt to expose a vulnerability with a diversionary shield bash on .+\!/,
          :usage      => "pin",
          :short_name => 'pin'
        },
        "shield_push"           => {
          :cost       => 7,
          :regex      => /You raise your .+ before you and attempt to push .+ away\!/,
          :usage      => "push",
          :short_name => 'push'
        },
        "shield_riposte"        => {
          :cost       => 20,
          :regex      => Regexp.union(/You assume the Shield Riposte Stance, preparing yourself to lash out at a moment's notice\./,
                                      /You re\-settle into the Shield Riposte Stance, preparing yourself to lash out at a moment's notice\./),
          :usage      => "riposte",
          :short_name => 'riposte'
        },
        "shield_spike_mastery"  => {
          :cost       => 0,
          :regex      => /Shield Spike Mastery does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil,
          :short_name => 'spikemastery'
        },
        "shield_strike"         => {
          :cost       => 15,
          :regex      => /You launch a quick bash with your .+ at .+\!/,
          :usage      => "strike",
          :short_name => 'strike'
        },
        "shield_strike_mastery" => {
          :cost       => 0,
          :regex      => /Shield Strike Mastery does not need to be activated once you have learned it\.  It will automatically apply to all relevant focused multi\-attacks, provided that you maintain the prerequisite ranks of Shield Bash\./,
          :usage      => nil,
          :short_name => 'strikemastery'
        },
        "shield_swiftness"      => {
          :cost       => 0,
          :regex      => /Shield Swiftness does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a small or medium shield and have at least 3 ranks of the relevant Shield Focus specialization\./,
          :usage      => nil,
          :short_name => 'swiftness'
        },
        "shield_throw"          => {
          :cost       => 20,
          :regex      => /You snap your arm forward, hurling your .+ at .+ with all your might\!/,
          :usage      => "throw",
          :short_name => 'throw'
        },
        "shield_trample"        => {
          :cost       => 14,
          :regex      => /You raise your .+ before you and charge headlong towards .+\!/,
          :usage      => "trample",
          :short_name => 'trample'
        },
        "shielded_brawler"      => {
          :cost       => 0,
          :regex      => /Shielded Brawler does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage      => nil,
          :short_name => 'brawler'
        },
        "small_shield_focus"    => {
          :cost       => 0,
          :regex      => /Small Shield Focus does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage      => nil,
          :short_name => 'sfocus'
        },
        "spell_block"           => {
          :cost       => 0,
          :regex      => /Spell Block does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage      => nil,
          :short_name => 'spellblock'
        },
        "steady_shield"         => {
          :cost       => 0,
          :regex      => /Steady Shield does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks against you, provided that you maintain the prerequisite ranks of Stun Maneuvers\./,
          :usage      => nil,
          :short_name => 'steady'
        },
        "steely_resolve"        => {
          :cost       => 30,
          :regex      => Regexp.union(/You focus your mind in a steely resolve to block all attacks against you\./,
                                      /You are still mentally fatigued from your last invocation of your Steely Resolve\./),
          :usage      => "resolve",
          :short_name => 'resolve'
        },
        "tortoise_stance"       => {
          :cost       => 20,
          :regex      => Regexp.union(/You assume the Stance of the Tortoise, holding back some of your offensive power in order to maximize your defense\./,
                                      /You re\-settle into the Stance of the Tortoise, holding back your offensive power in order to maximize your defense\./),
          :usage      => "tortoise",
          :short_name => 'tortoise'
        },
        "tower_shield_focus"    => {
          :cost       => 0,
          :regex      => /Tower Shield Focus does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./i,
          :usage      => nil,
          :short_name => 'tfocus'
        },
      }

      # symbol_lookups
      def self.shield_lookups
        @@shield_techniques.map do |long_name, psm|
          {
            long_name: long_name,
            short_name: psm[:short_name],
            cost: calculate_cost(psm[:short_name])
          }
        end
      end

      def Shield.[](name)
        return PSMS.assess(name, 'Shield')
      end

      def Shield.known?(name, min_rank: 1)
        min_rank = 1 unless min_rank >= 1 # in case a 0 or below is passed
        Shield[name] >= min_rank
      end

      def Shield.affordable?(name, forcert_count: 0)
        return PSMS.assess(name, 'Shield', true, forcert_count: forcert_count)
      end

      def Shield.available?(name, min_rank: 1, forcert_count: 0)
        Shield.known?(name, min_rank: min_rank) and Shield.affordable?(name, forcert_count: forcert_count) and !Lich::Util.normalize_lookup('Cooldowns', name) and !Lich::Util.normalize_lookup('Debuffs', 'Overexerted')
      end

      def Shield.use(name, target = "", results_of_interest: nil, forcert_count: 0)
        return unless Shield.available?(name, forcert_count: forcert_count)
        name_normalized = PSMS.name_normal(name)
        technique = @@shield_techniques.fetch(name_normalized)
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

        if results_of_interest.is_a?(Regexp)
          results_regex = Regexp.union(results_regex, results_of_interest)
        end

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

      def Shield.regexp(name)
        @@shield_techniques.fetch(PSMS.name_normal(name))[:regex]
      end

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
