## breakout for Armor released with PSM3
## new code for 5.0.16
## includes new functions .known? and .affordable?

class Armor
  @@armor_blessing                ||= 0
  @@armor_reinforcement           ||= 0
  @@armor_spike_mastery           ||= 0
  @@armor_support                 ||= 0
  @@armored_casting               ||= 0
  @@armored_evasion               ||= 0
  @@armored_fluidity              ||= 0
  @@armored_stealth               ||= 0
  @@crush_protection              ||= 0
  @@puncture_protection           ||= 0
  @@slash_protection              ||= 0

  def Armor.armor_blessing;              @@armor_blessing;             end
  def Armor.armor_reinforcement;         @@armor_reinforcement;        end
  def Armor.armor_spike_mastery;         @@armor_spike_mastery;        end
  def Armor.armor_support;               @@armor_support;              end
  def Armor.armored_casting;             @@armored_casting;            end
  def Armor.armored_evasion;             @@armored_evasion;            end
  def Armor.armored_fluidity;            @@armored_fluidity;           end
  def Armor.armored_stealth;             @@armored_stealth;            end
  def Armor.crush_protection;            @@crush_protection;           end
  def Armor.puncture_protection;         @@puncture_protection;        end
  def Armor.slash_protection;            @@slash_protection;           end

  def Armor.armor_blessing=(val);        @@armor_blessing=val;         end
  def Armor.armor_reinforcement=(val);   @@armor_reinforcement=val;    end
  def Armor.armor_spike_mastery=(val);   @@armor_spike_mastery=val;    end
  def Armor.armor_support=(val);         @@armor_support=val;          end
  def Armor.armored_casting=(val);       @@armored_casting=val;        end
  def Armor.armored_evasion=(val);       @@armored_evasion=val;        end
  def Armor.armored_fluidity=(val);      @@armored_fluidity=val;       end
  def Armor.armored_stealth=(val);       @@armored_stealth=val;        end
  def Armor.crush_protection=(val);      @@crush_protection=val;       end
  def Armor.puncture_protection=(val);   @@puncture_protection=val;    end
  def Armor.slash_protection=(val);      @@slash_protection=val;       end

  @@armor_techniques = {
    "armor_blessing" => {
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
    "armor_support" => {
      :regex => /\w+ adjusts? \w+(?:'s)? [\w\s]+, improving its ability to support the weight of \w+ gear\./i,
      :usage => "support",
    },
    "armored_casting" => {
      :regex => /\w+ adjusts? \w+(?:'s)? [\w\s]+, making it easier for \w+ to recover from failed spell casting\./i,
      :usage => "casting",
    },
    "armored_evasion" => {
      :regex => /\w+ adjusts? \w+(?:'s)? [\w\s]+, improving its comfort and maneuverability\./i,
      :usage => "evasion",
    },
    "armored_fluidity" => {
      :regex => /\w+ adjusts? \w+(?:'s)? [\w\s]+, making it easier for \w+ to cast spells\./i,
      :usage => "fluidity",
    },
    "armored_stealth" => {
      :regex => /\w+ adjusts? \w+(?:'s)? [\w\s]+ to cushion \w+ movements\./i,
      :usage => "stealth",
    },
    "crush_protection" => {
      :regex => /You adjusts? \w+(?:'s)? [\w\s]+ with your plate armor fittings, rearranging and reinforcing the armor to better protect against (?:punctur|crush|slash)ing damage\.|You must specify an armor slot\.|You don't seem to have the necessary armor fittings in hand\./i,
      :usage => "crush",
    },
    "puncture_protection" => {
      :regex => /You adjusts? \w+(?:'s)? [\w\s]+ with your plate armor fittings, rearranging and reinforcing the armor to better protect against (?:punctur|crush|slash)ing damage\.|You must specify an armor slot\.|You don't seem to have the necessary armor fittings in hand\./i,
      :usage => "puncture",
    },
    "slash_protection" => {
      :regex => /You adjusts? \w+(?:'s)? [\w\s]+ with your plate armor fittings, rearranging and reinforcing the armor to better protect against (?:punctur|crush|slash)ing damage\.|You must specify an armor slot\.|You don't seem to have the necessary armor fittings in hand\./i,
      :usage => "slash",
    },
  }

  def Armor.method_missing(arg1, arg2=nil)
    echo "#{arg1} is not a defined Armor type.  Is it another Ability type?"
  end
  def Armor.[](name)
    Armor.send(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase)
  end
  def Armor.[]=(name,val)
    Armor.send("#{name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase}=", val.to_i)
  end

  def Armor.known?(name)
    Armor.send(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase) > 0
  end

  ## Armor does not require stamina so costs are zero across the board
  ## the following method is in place simply to make consistent with other
  ## PSM class definitions.  
  def Armor.affordable?(name)
    return true
  end

  def Armor.available?(name)
    Armor.known?(name) and Armor.affordable?(name)
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

end
