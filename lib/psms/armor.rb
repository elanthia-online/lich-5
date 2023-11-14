## breakout for Armor released with PSM3
## updated for Ruby 3.2.1 and new Infomon module

module Armor
  # rubocop:disable Layout/ExtraSpacing
  def self.armor_lookups
    [{ long_name: 'armor_blessing',	        short_name: 'blessing',	        cost:	 0 },
     { long_name: 'armor_reinforcement',	  short_name: 'reinforcement',	  cost:	 0 },
     { long_name: 'armor_spike_mastery',	  short_name: 'spikemastery',	    cost:	 0 },
     { long_name: 'armor_support',	        short_name: 'support',	        cost:	 0 },
     { long_name: 'armored_casting',	      short_name: 'casting',	        cost:	 0 },
     { long_name: 'armored_evasion',	      short_name: 'evasion',	        cost:	 0 },
     { long_name: 'armored_fluidity',	      short_name: 'fluidity',	        cost:	 0 },
     { long_name: 'armored_stealth',	      short_name: 'stealth',	        cost:	 0 },
     { long_name: 'crush_protection',	      short_name: 'crush',	          cost:	 0 },
     { long_name: 'puncture_protection',	  short_name: 'puncture',	        cost:	 0 },
     { long_name: 'slash_protection',	      short_name: 'slash',	          cost:	 0 }]
    # rubocop:enable Layout/ExtraSpacing
  end

  @@armor_techniques = {
    "armor_blessing"      => {
      :regex => /As \w+ prays? over \w+(?:'s)? [\w\s]+, you sense that (?:the Arkati's|a) blessing will be granted against magical attacks\./i,
      :usage => "blessing",
    },
    "armor_reinforcement" => {
      :regex => /\w+ adjusts? \w+(?:'s)? [\w\s]+, reinforcing weak spots\./i,
      :usage => "reinforcement",
    },
    "armor_spike_mastery" => {
      :regex => /Armor Spike Mastery is passive and always active once learned\./i,
      :usage => "spikemastery",
    },
    "armor_support"       => {
      :regex => /\w+ adjusts? \w+(?:'s)? [\w\s]+, improving its ability to support the weight of \w+ gear\./i,
      :usage => "support",
    },
    "armored_casting"     => {
      :regex => /\w+ adjusts? \w+(?:'s)? [\w\s]+, making it easier for \w+ to recover from failed spell casting\./i,
      :usage => "casting",
    },
    "armored_evasion"     => {
      :regex => /\w+ adjusts? \w+(?:'s)? [\w\s]+, improving its comfort and maneuverability\./i,
      :usage => "evasion",
    },
    "armored_fluidity"    => {
      :regex => /\w+ adjusts? \w+(?:'s)? [\w\s]+, making it easier for \w+ to cast spells\./i,
      :usage => "fluidity",
    },
    "armored_stealth"     => {
      :regex => /\w+ adjusts? \w+(?:'s)? [\w\s]+ to cushion \w+ movements\./i,
      :usage => "stealth",
    },
    "crush_protection"    => {
      :regex => /You adjusts? \w+(?:'s)? [\w\s]+ with your plate armor fittings, rearranging and reinforcing the armor to better protect against (?:punctur|crush|slash)ing damage\.|You must specify an armor slot\.|You don't seem to have the necessary armor fittings in hand\./i,
      :usage => "crush",
    },
    "puncture_protection" => {
      :regex => /You adjusts? \w+(?:'s)? [\w\s]+ with your plate armor fittings, rearranging and reinforcing the armor to better protect against (?:punctur|crush|slash)ing damage\.|You must specify an armor slot\.|You don't seem to have the necessary armor fittings in hand\./i,
      :usage => "puncture",
    },
    "slash_protection"    => {
      :regex => /You adjusts? \w+(?:'s)? [\w\s]+ with your plate armor fittings, rearranging and reinforcing the armor to better protect against (?:punctur|crush|slash)ing damage\.|You must specify an armor slot\.|You don't seem to have the necessary armor fittings in hand\./i,
      :usage => "slash",
    },
  }

  def Armor.[](name)
    return PSMS.assess(name, 'Armor')
  end

  def Armor.known?(name)
    Armor[name] > 0
  end

  def Armor.affordable?(name)
    return PSMS.assess(name, 'Armor', true)
  end

  def Armor.available?(name)
    Armor.known?(name) and Armor.affordable?(name) and !Lich::Util.normalize_lookup('Cooldowns', name) and !Lich::Util.normalize_lookup('Debuffs', 'Overexerted')
  end

  def Armor.use(name, target = "")
    return unless Armor.available?(name)
    usage = @@armor_techniques.fetch(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase)[:usage]
    return if usage.nil?

    results_regex = Regexp.union(
      @@armor_techniques.fetch(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase)[:regex],
      /^#{name} what\?$/i,
      /^Roundtime: [0-9]+ sec\.$/,
      /^And give yourself away!  Never!$/,
      /^You are unable to do that right now\.$/,
      /^You don't seem to be able to move to do that\.$/,
      /^Provoking a GameMaster is not such a good idea\.$/,
      /^You do not currently have a target\.$/,
    )
    usage_cmd = "armor #{usage}"
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

  Armor.armor_lookups.each { |armor|
    self.define_singleton_method(armor[:short_name]) do
      Armor[armor[:short_name]]
    end

    self.define_singleton_method(armor[:long_name]) do
      Armor[armor[:short_name]]
    end
  }
end
