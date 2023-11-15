## breakout for Shield released with PSM3
## new code for 5.0.16
## includes new functions .known? and .affordable?

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
      :regex => /Adamantine Bulwark does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
      :usage => nil,
    },
    "block_the_elements"    => {
      :cost  => 0,
      :regex => /Block the Elements does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
      :usage => nil,
    },
    "deflect_magic"         => {
      :cost  => 0,
      :regex => /Deflect Magic does not need to be activated once you have learned it.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization./i,
      :usage => nil,
    },
    "deflect_missiles"      => {
      :cost  => 0,
      :regex => /Deflect Missiles does not need to be activated once you have learned it.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization./i,
      :usage => nil,
    },
    "deflect_the_elements"  => {
      :cost  => 0,
      :regex => /Deflect the Elements does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
      :usage => nil,
    },
    "disarming_presence"    => {
      :cost  => 20,
      :regex => /You assume the Disarming Presence Stance, adjusting your footing and grip to allow for the proper pivot and thrust technique to disarm attacking foes.|You re-settle into the Disarming Presence Stance, re-ensuring your footing and grip are properly positioned./i,
      :usage => "dpresence",
    },
    "guard_mastery"         => {
      :cost  => 0,
      :regex => /Guard Mastery does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
      :usage => nil,
    },
    "large_shield_focus"    => {
      :cost  => 0,
      :regex => /Large Shield Focus does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
      :usage => nil,
    },
    "medium_shield_focus"   => {
      :cost  => 0,
      :regex => /Medium Shield Focus does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
      :usage => nil,
    },
    "phalanx"               => {
      :cost  => 0,
      :regex => /Phalanx does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
      :usage => nil,
    },
    "prop_up"               => {
      :cost  => 0,
      :regex => /Prop Up does not need to be activated once you have learned it.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization./i,
      :usage => nil,
    },
    "protective_wall"       => {
      :cost  => 0,
      :regex => /Protective Wall does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
      :usage => nil,
    },
    "shield_bash"           => {
      :cost  => 9,
      :regex => /Shield Bash what?|You lunge forward at (.*) with your (.*) and attempt a shield bash\!/i,
      :usage => "bash",
    },
    "shield_charge"         => {
      :cost  => 14,
      :regex => /You charge forward at (.*) with your (.*) and attempt a shield charge!/i,
      :usage => "charge",
    },
    "shield_forward"        => {
      :cost  => 0,
      :regex => /Shield Forward does not need to be activated once you have learned it.  It will automatically activate upon the use of a shield attack./i,
      :usage => "forward",
    },
    "shield_mind"           => {
      :cost  => 10,
      :regex => /You must be wielding an ensorcelled or anti-magical shield to be able to properly shield your mind and soul.|/i,
      :usage => "mind",
    },
    "shield_pin"            => {
      :cost  => 15,
      :regex => /You attempt to expose a vulnerability with a diversionary shield bash on (.*)\!/i,
      :usage => "pin",
    },
    "shield_push"           => {
      :cost  => 7,
      :regex => /You raise your (.*) before you and attempt to push (.*) away!/i,
      :usage => "push",
    },
    "shield_riposte"        => {
      :cost  => 20,
      :regex => /You assume the Shield Riposte Stance, preparing yourself to lash out at a moment's notice.|You re\-settle into the Shield Riposte Stance, preparing yourself to lash out at a moment's notice./i,
      :usage => "riposte",
    },
    "shield_spike_mastery"  => {
      :cost  => 0,
      :regex => /Shield Spike Mastery does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
      :usage => nil,
    },
    "shield_strike"         => {
      :cost  => 15,
      :regex => /You launch a quick bash with your (.*) at (.*)\!/i,
      :usage => "strike",
    },
    "shield_strike_mastery" => {
      :cost  => 0,
      :regex => /Shield Strike Mastery does not need to be activated once you have learned it.  It will automatically apply to all relevant focused multi-attacks, provided that you maintain the prerequisite ranks of Shield Bash./i,
      :usage => nil,
    },
    "shield_swiftness"      => {
      :cost  => 0,
      :regex => /Shield Swiftness does not need to be activated once you have learned it.  It will automatically apply to all relevant attacks, provided that you are wielding a small or medium shield and have at least 3 ranks of the relevant Shield Focus specialization./i,
      :usage => nil,
    },
    "shield_throw"          => {
      :cost  => 20,
      :regex => /You snap your arm forward, hurling your (.*) at (.*) with all your might\!/i,
      :usage => "throw",
    },
    "shield_trample"        => {
      :cost  => 14,
      :regex => /You raise your (.*) before you and charge headlong towards (.*)\!/i,
      :usage => "trample",
    },
    "shielded_brawler"      => {
      :cost  => 0,
      :regex => /Shielded Brawler does not need to be activated once you have learned it.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization./i,
      :usage => nil,
    },
    "small_shield_focus"    => {
      :cost  => 0,
      :regex => /Small Shield Focus does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
      :usage => nil,
    },
    "spell_block"           => {
      :cost  => 0,
      :regex => /Spell Block does not need to be activated once you have learned it.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization./i,
      :usage => nil,
    },
    "steady_shield"         => {
      :cost  => 0,
      :regex => /Steady Shield does not need to be activated once you have learned it.  It will automatically apply to all relevant attacks against you, provided that you maintain the prerequisite ranks of Stun Maneuvers./i,
      :usage => nil,
    },
    "steely_resolve"        => {
      :cost  => 30,
      :regex => /You focus your mind in a steely resolve to block all attacks against you.|You are still mentally fatigued from your last invocation of your Steely Resolve./i,
      :usage => "resolve",
    },
    "tortoise_stance"       => {
      :cost  => 20,
      :regex => /You assume the Stance of the Tortoise, holding back some of your offensive power in order to maximize your defense.|You re\-settle into the Stance of the Tortoise, holding back your offensive power in order to maximize your defense./i,
      :usage => "tortoise",
    },
    "tower_shield_focus"    => {
      :cost  => 0,
      :regex => /Tower Shield Focus does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
      :usage => nil,
    },
  }
  def Shield.[](name)
    return PSMS.assess(name, 'Shield')
  end

  def Shield.known?(name)
    Shield[name] > 0
  end

  def Shield.affordable?(name)
    return PSMS.assess(name, 'Shield', true)
  end

  def Shield.available?(name)
    Shield.known?(name) and Shield.affordable?(name) and !Lich::Util.normalize_lookup('Cooldowns', name) and !Lich::Util.normalize_lookup('Debuffs', 'Overexerted')
  end

  # unmodified from 5.6.2
  def Shield.use(name, target = "")
    return unless Shield.available?(name)
    usage = @@shield_techniques.fetch(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase)[:usage]
    return if usage.nil?

    results_regex = Regexp.union(
      @@shield_techniques.fetch(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase)[:regex],
      /^#{name} what\?$/i,
      /^Roundtime: [0-9]+ sec\.$/,
      /^And give yourself away!  Never!$/,
      /^You are unable to do that right now\.$/,
      /^You don't seem to be able to move to do that\.$/,
      /^Provoking a GameMaster is not such a good idea\.$/,
      /^You do not currently have a target\.$/,
    )
    usage_cmd = "shield #{usage}"
    if target.class == GameObj
      usage_cmd += " ##{target.id}"
    elsif target.class == Integer
      usage_cmd += " ##{target}"
    elsif target != ""
      usage_cmd += " #{target}"
    end
    usage_result = nil
    loop {
      waitrt?
      waitcastrt?
      usage_result = dothistimeout usage_cmd, 5, results_regex
      if usage_result == "You don't seem to be able to move to do that."
        100.times { break if clear.any? { |line| line =~ /^You regain control of your senses!$/ }; sleep 0.1 }
        usage_result = dothistimeout usage_cmd, 5, results_regex
      end
      break
    }
    usage_result
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
