## breakout for Shield released with PSM3
## new code for 5.0.16
## includes new functions .known? and .affordable?
module Lich
  module Gemstone
    module Shield
      def self.shield_lookups
        # rubocop:disable Layout/ExtraSpacing
        [{ long_name: 'acrobats_leap',           short_name: 'acrobatsleap',    cost:  0 },
         { long_name: 'adamantine_bulwark', 	   short_name: 'bulwark', 	      cost:  0 },
         { long_name: 'block_the_elements', 	   short_name: 'blockelements',	  cost:  0 },
         { long_name: 'deflect_magic',           short_name: 'deflectmagic',    cost:  0 },
         { long_name: 'deflect_missiles', 	     short_name: 'deflectmissiles', cost:  0 },
         { long_name: 'deflect_the_elements', 	 short_name: 'deflectelements', cost:  0 },
         { long_name: 'disarming_presence', 	   short_name: 'dpresence', 	    cost: 20 },
         { long_name: 'guard_mastery',           short_name: 'gmastery',        cost:  0 },
         { long_name: 'large_shield_focus',      short_name: 'lfocus',          cost:  0 },
         { long_name: 'medium_shield_focus', 	   short_name: 'mfocus',          cost:  0 },
         { long_name: 'phalanx', 	               short_name: 'phalanx',         cost:  0 },
         { long_name: 'prop_up', 	               short_name: 'prop',            cost:  0 },
         { long_name: 'protective_wall', 	       short_name: 'pwall',           cost:  0 },
         { long_name: 'shield_bash', 	           short_name: 'bash', 	          cost:  9 },
         { long_name: 'shield_charge', 	         short_name: 'charge', 	        cost: 14 },
         { long_name: 'shield_forward',          short_name: 'forward',         cost:  0 },
         { long_name: 'shield_mind',             short_name: 'mind',            cost: 10 },
         { long_name: 'shield_pin',              short_name: 'pin',             cost: 15 },
         { long_name: 'shield_push',             short_name: 'push',            cost:  7 },
         { long_name: 'shield_riposte', 	       short_name: 'riposte',         cost: 20 },
         { long_name: 'shield_spike_mastery', 	 short_name: 'spikemastery',    cost:  0 },
         { long_name: 'shield_strike', 	         short_name: 'strike',          cost: 15 },
         { long_name: 'shield_strike_mastery', 	 short_name: 'strikemastery',   cost:  0 },
         { long_name: 'shield_swiftness', 	     short_name: 'swiftness', 	    cost:  0 },
         { long_name: 'shield_throw', 	         short_name: 'throw', 	        cost: 20 },
         { long_name: 'shield_trample', 	       short_name: 'trample', 	      cost: 14 },
         { long_name: 'shielded_brawler', 	     short_name: 'brawler', 	      cost:  0 },
         { long_name: 'small_shield_focus', 	   short_name: 'sfocus',          cost:  0 },
         { long_name: 'spell_block', 	           short_name: 'spellblock', 	    cost:  0 },
         { long_name: 'steady_shield', 	         short_name: 'steady', 	        cost:  0 },
         { long_name: 'steely_resolve',          short_name: 'resolve',         cost: 30 },
         { long_name: 'tortoise_stance',         short_name: 'tortoise',        cost: 20 },
         { long_name: 'tower_shield_focus',      short_name: 'tfocus',          cost:  0 }]
        # rubocop:enable Layout/ExtraSpacing
      end
      # unmodified from 5.6.2
      @@shield_techniques = {
        "adamantine_bulwark"    => {
          :cost  => 0,
          :regex => /Adamantine Bulwark does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage => nil,
        },
        "block_the_elements"    => {
          :cost  => 0,
          :regex => /Block the Elements does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage => nil,
        },
        "deflect_magic"         => {
          :cost  => 0,
          :regex => /Deflect Magic does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage => nil,
        },
        "deflect_missiles"      => {
          :cost  => 0,
          :regex => /Deflect Missiles does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage => nil,
        },
        "deflect_the_elements"  => {
          :cost  => 0,
          :regex => /Deflect the Elements does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage => nil,
        },
        "disarming_presence"    => {
          :cost  => 20,
          :regex => Regexp.union(/You assume the Disarming Presence Stance, adjusting your footing and grip to allow for the proper pivot and thrust technique to disarm attacking foes\./,
                                 /You re\-settle into the Disarming Presence Stance, re-ensuring your footing and grip are properly positioned\./),
          :usage => "dpresence",
        },
        "guard_mastery"         => {
          :cost  => 0,
          :regex => /Guard Mastery does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage => nil,
        },
        "large_shield_focus"    => {
          :cost  => 0,
          :regex => /Large Shield Focus does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage => nil,
        },
        "medium_shield_focus"   => {
          :cost  => 0,
          :regex => /Medium Shield Focus does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage => nil,
        },
        "phalanx"               => {
          :cost  => 0,
          :regex => /Phalanx does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage => nil,
        },
        "prop_up"               => {
          :cost  => 0,
          :regex => /Prop Up does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage => nil,
        },
        "protective_wall"       => {
          :cost  => 0,
          :regex => /Protective Wall does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage => nil,
        },
        "shield_bash"           => {
          :cost  => 9,
          :regex => /You lunge forward at .+ with your .+ and attempt a shield bash\!/,
          :usage => "bash",
        },
        "shield_charge"         => {
          :cost  => 14,
          :regex => /You charge forward at .+ with your .+ and attempt a shield charge\!/,
          :usage => "charge",
        },
        "shield_forward"        => {
          :cost  => 0,
          :regex => /Shield Forward does not need to be activated once you have learned it\.  It will automatically activate upon the use of a shield attack\./,
          :usage => "forward",
        },
        "shield_mind"           => {
          :cost  => 10,
          :regex => /You must be wielding an ensorcelled or anti-magical shield to be able to properly shield your mind and soul\./,
          :usage => "mind",
        },
        "shield_pin"            => {
          :cost  => 15,
          :regex => /You attempt to expose a vulnerability with a diversionary shield bash on .+\!/,
          :usage => "pin",
        },
        "shield_push"           => {
          :cost  => 7,
          :regex => /You raise your .+ before you and attempt to push .+ away\!/,
          :usage => "push",
        },
        "shield_riposte"        => {
          :cost  => 20,
          :regex => Regexp.union(/You assume the Shield Riposte Stance, preparing yourself to lash out at a moment's notice\./,
                                 /You re\-settle into the Shield Riposte Stance, preparing yourself to lash out at a moment's notice\./),
          :usage => "riposte",
        },
        "shield_spike_mastery"  => {
          :cost  => 0,
          :regex => /Shield Spike Mastery does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage => nil,
        },
        "shield_strike"         => {
          :cost  => 15,
          :regex => /You launch a quick bash with your .+ at .+\!/,
          :usage => "strike",
        },
        "shield_strike_mastery" => {
          :cost  => 0,
          :regex => /Shield Strike Mastery does not need to be activated once you have learned it\.  It will automatically apply to all relevant focused multi\-attacks, provided that you maintain the prerequisite ranks of Shield Bash\./,
          :usage => nil,
        },
        "shield_swiftness"      => {
          :cost  => 0,
          :regex => /Shield Swiftness does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a small or medium shield and have at least 3 ranks of the relevant Shield Focus specialization\./,
          :usage => nil,
        },
        "shield_throw"          => {
          :cost  => 20,
          :regex => /You snap your arm forward, hurling your .+ at .+ with all your might\!/,
          :usage => "throw",
        },
        "shield_trample"        => {
          :cost  => 14,
          :regex => /You raise your .+ before you and charge headlong towards .+\!/,
          :usage => "trample",
        },
        "shielded_brawler"      => {
          :cost  => 0,
          :regex => /Shielded Brawler does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage => nil,
        },
        "small_shield_focus"    => {
          :cost  => 0,
          :regex => /Small Shield Focus does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./,
          :usage => nil,
        },
        "spell_block"           => {
          :cost  => 0,
          :regex => /Spell Block does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization\./,
          :usage => nil,
        },
        "steady_shield"         => {
          :cost  => 0,
          :regex => /Steady Shield does not need to be activated once you have learned it\.  It will automatically apply to all relevant attacks against you, provided that you maintain the prerequisite ranks of Stun Maneuvers\./,
          :usage => nil,
        },
        "steely_resolve"        => {
          :cost  => 30,
          :regex => Regexp.union(/You focus your mind in a steely resolve to block all attacks against you\./,
                                 /You are still mentally fatigued from your last invocation of your Steely Resolve\./),
          :usage => "resolve",
        },
        "tortoise_stance"       => {
          :cost  => 20,
          :regex => Regexp.union(/You assume the Stance of the Tortoise, holding back some of your offensive power in order to maximize your defense\./,
                                 /You re\-settle into the Stance of the Tortoise, holding back your offensive power in order to maximize your defense\./),
          :usage => "tortoise",
        },
        "tower_shield_focus"    => {
          :cost  => 0,
          :regex => /Tower Shield Focus does not need to be activated\.  If you are wielding the appropriate type of shield, it will always be active\./i,
          :usage => nil,
        },
      }
      def Shield.[](name)
        return PSMS.assess(name, 'Shield')
      end

      def Shield.known?(name, min_rank: 1)
        min_rank = 1 unless min_rank >= 1 # in case a 0 or below is passed
        Shield[name] >= min_rank
      end

      def Shield.affordable?(name)
        return PSMS.assess(name, 'Shield', true)
      end

      def Shield.available?(name, min_rank: 1)
        Shield.known?(name, min_rank: min_rank) and Shield.affordable?(name) and !Lich::Util.normalize_lookup('Cooldowns', name) and !Lich::Util.normalize_lookup('Debuffs', 'Overexerted')
      end

      # unmodified from 5.6.2
      def Shield.use(name, target = "", results_of_interest: nil)
        return unless Shield.available?(name)
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
        waitrt?
        waitcastrt?
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
