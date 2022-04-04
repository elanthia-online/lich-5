## breakout for Shield released with PSM3
## new code for 5.0.16
## includes new functions .known? and .affordable?

class Shield
  @@adamantine_bulwark            ||= 0
  @@block_the_elements            ||= 0
  @@deflect_magic                 ||= 0
  @@deflect_missiles              ||= 0
  @@deflect_the_elements          ||= 0
  @@disarming_presence            ||= 0
  @@guard_mastery                 ||= 0
  @@large_shield_focus            ||= 0
  @@medium_shield_focus           ||= 0
  @@phalanx                       ||= 0
  @@prop_up                       ||= 0
  @@protective_wall               ||= 0
  @@shield_bash                   ||= 0
  @@shield_charge                 ||= 0
  @@shield_forward                ||= 0
  @@shield_mind                   ||= 0
  @@shield_pin                    ||= 0
  @@shield_push                   ||= 0
  @@shield_riposte                ||= 0
  @@shield_spike_mastery          ||= 0
  @@shield_strike                 ||= 0
  @@shield_strike_mastery         ||= 0
  @@shield_swiftness              ||= 0
  @@shield_throw                  ||= 0
  @@shield_trample                ||= 0
  @@shielded_brawler              ||= 0
  @@small_shield_focus            ||= 0
  @@spell_block                   ||= 0
  @@steady_shield                 ||= 0
  @@steely_resolve                ||= 0
  @@tortoise_stance               ||= 0
  @@tower_shield_focus            ||= 0


  def Shield.adamantine_bulwark;        @@aadamantine_bulwark;          end
  def Shield.block_the_elements;        @@block_the_elements;           end
  def Shield.deflect_magic;             @@deflect_magic;                end
  def Shield.deflect_missiles;          @@deflect_missiles;             end
  def Shield.deflect_the_elements;      @@deflect_the_elements;         end
  def Shield.disarming_presence;        @@disarming_presence;           end
  def Shield.guard_mastery;             @@guard_mastery;                end
  def Shield.large_shield_focus;        @@large_shield_focus;           end
  def Shield.medium_shield_focus;       @@medium_shield_focus;          end
  def Shield.phalanx;                   @@phalanx;                      end
  def Shield.prop_up;                   @@prop_up;                      end
  def Shield.protective_wall;           @@protective_wall;              end
  def Shield.shield_bash;               @@shield_bash;                  end
  def Shield.shield_charge;             @@shield_charge;                end
  def Shield.shield_forward;            @@shield_forward;               end
  def Shield.shield_mind;               @@shield_mind;                  end
  def Shield.shield_pin;                @@shield_pin;                   end
  def Shield.shield_push;               @@shield_push;                  end
  def Shield.shield_riposte;            @@shield_riposte;               end
  def Shield.shield_spike_mastery;      @@shield_spike_mastery;         end
  def Shield.shield_strike;             @@shield_strike;                end
  def Shield.shield_strike_mastery;     @@shield_strike_mastery;        end
  def Shield.shield_swiftness;          @@shield_swiftness;             end
  def Shield.shield_throw;              @@shield_throw;                 end
  def Shield.shield_trample;            @@shield_trample;               end
  def Shield.shielded_brawler;          @@shielded_brawler;             end
  def Shield.small_shield_focus;        @@small_shield_focus;           end
  def Shield.spell_block;               @@spell_block;                  end
  def Shield.steady_shield;             @@steady_shield;                end
  def Shield.steely_resolve;            @@steely_resolve;               end
  def Shield.tortoise_stance;           @@tortoise_stance;              end
  def Shield.tower_shield_focus;        @@tower_shield_focus;           end

  def Shield.adamantine_bulwark=(val);    @@adamantine_bulwark=val;     end
  def Shield.block_the_elements=(val);    @@block_the_elements=val;     end
  def Shield.deflect_magic=(val);         @@deflect_magic=val;          end
  def Shield.deflect_missiles=(val);      @@deflect_missiles=val;       end
  def Shield.deflect_the_elements=(val);  @@deflect_the_elements=val;   end
  def Shield.disarming_presence=(val);    @@disarming_presence=val;     end
  def Shield.guard_mastery=(val);         @@guard_mastery=val;          end
  def Shield.large_shield_focus=(val);    @@large_shield_focus=val;     end
  def Shield.medium_shield_focus=(val);   @@medium_shield_focus=val;    end
  def Shield.phalanx=(val);               @@phalanx=val;                end
  def Shield.prop_up=(val);               @@prop_up=val;                end
  def Shield.protective_wall=(val);       @@protective_wall=val;        end
  def Shield.shield_bash=(val);           @@shield_bash=val;            end
  def Shield.shield_charge=(val);         @@shield_charge=val;          end
  def Shield.shield_forward=(val);        @@shield_forward=val;         end
  def Shield.shield_mind=(val);           @@shield_mind=val;            end
  def Shield.shield_pin=(val);            @@shield_pin=val;             end
  def Shield.shield_push=(val);           @@shield_push=val;            end
  def Shield.shield_riposte=(val);        @@shield_riposte=val;         end
  def Shield.shield_spike_mastery=(val);  @@shield_spike_mastery=val;   end
  def Shield.shield_strike=(val);         @@shield_strike=val;          end
  def Shield.shield_strike_mastery=(val); @@shield_strike_mastery=val;  end
  def Shield.shield_swiftness=(val);      @@shield_swiftness=val;       end
  def Shield.shield_throw=(val);          @@shield_throw=val;           end
  def Shield.shield_trample=(val);        @@shield_trample=val;         end
  def Shield.shielded_brawler=(val);      @@shielded_brawler=val;       end
  def Shield.small_shield_focus=(val);    @@small_shield_focus=val;     end
  def Shield.spell_block=(val);           @@spell_block=val;            end
  def Shield.steady_shield=(val);         @@steady_shield=val;          end
  def Shield.steely_resolve=(val);        @@steely_resolve=val;         end
  def Shield.tortoise_stance=(val);       @@tortoise_stance=val;        end
  def Shield.tower_shield_focus=(val);    @@tower_shield_focus=val;     end

  @@cost_hash = { 
    "adamantine_bulwark"    => 0, 
    "block_the_elements"    => 0, 
    "deflect_magic"         => 0, 
    "deflect_missiles"      => 0, 
    "deflect_the_elements"  => 0, 
    "disarming_presence"    => 20, 
    "guard_mastery"         => 0, 
    "large_shield_focus"    => 0, 
    "medium_shield_focus"   => 0, 
    "phalanx"               => 0, 
    "prop_up"               => 0, 
    "protective_wall"       => 0, 
    "shield_bash"           => 9, 
    "shield_charge"         => 14, 
    "shield_forward"        => 0, 
    "shield_mind"           => 10, 
    "shield_pin"            => 15, 
    "shield_push"           => 7, 
    "shield_riposte"        => 20, 
    "shield_spike_mastery"  => 0, 
    "shield_strike"         => 15, 
    "shield_strike_mastery" => 0, 
    "shield_swiftness"      => 0, 
    "shield_throw"          => 20, 
    "shield_trample"        => 14,
    "shielded_brawler"      => 0, 
    "small_shield_focus"    => 0, 
    "spell_block"           => 0, 
    "steady_shield"         => 0, 
    "steely_resolve"        => 30, 
    "tortoise_stance"       => 20, 
    "tower_shield_focus"    => 0 
  }
  
  @@regex_hash = {
	"adamantine_bulwark"    => /Adamantine Bulwark does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
	"block_the_elements"    => /Block the Elements does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
	"deflect_magic"         => /Deflect Magic does not need to be activated once you have learned it.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization./i,
	"deflect_missiles"      => /Deflect Missiles does not need to be activated once you have learned it.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization./i,
	"deflect_the_elements"  => /Deflect the Elements does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
	"disarming_presence"    => /You assume the Disarming Presence Stance, adjusting your footing and grip to allow for the proper pivot and thrust technique to disarm attacking foes.|You re-settle into the Disarming Presence Stance, re-ensuring your footing and grip are properly positioned./i,
	"guard_mastery"         => /Guard Mastery does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
	"large_shield_focus"    => /Large Shield Focus does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
	"medium_shield_focus"   => /Medium Shield Focus does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
	"phalanx"               => /Phalanx does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
	"prop_up"               => /Prop Up does not need to be activated once you have learned it.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization./i,
	"protective_wall"       => /Protective Wall does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
	"shield_bash"           => /Shield Bash what?|You lunge forward at (.*) with your (.*) and attempt a shield bash\!/i,
	"shield_charge"         => /You charge forward at (.*) with your (.*) and attempt a shield charge!/i,
	"shield_forward"        => /Shield Forward does not need to be activated once you have learned it.  It will automatically activate upon the use of a shield attack./i,
	"shield_mind"           => /You must be wielding an ensorcelled or anti-magical shield to be able to properly shield your mind and soul.|/i,
	"shield_pin"            => /You attempt to expose a vulnerability with a diversionary shield bash on (.*)\!/i,
	"shield_push"           => /You raise your (.*) before you and attempt to push (.*) away!/i,
	"shield_riposte"        => /You assume the Shield Riposte Stance, preparing yourself to lash out at a moment's notice.|You re\-settle into the Shield Riposte Stance, preparing yourself to lash out at a moment's notice./i,
	"shield_spike_mastery"  => /Shield Spike Mastery does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
	"shield_strike"         => /You launch a quick bash with your (.*) at (.*)\!/i,
	"shield_strike_mastery" => /Shield Strike Mastery does not need to be activated once you have learned it.  It will automatically apply to all relevant focused multi-attacks, provided that you maintain the prerequisite ranks of Shield Bash./i,
	"shield_swiftness"      => /Shield Swiftness does not need to be activated once you have learned it.  It will automatically apply to all relevant attacks, provided that you are wielding a small or medium shield and have at least 3 ranks of the relevant Shield Focus specialization./i,
	"shield_throw"          => /You snap your arm forward, hurling your (.*) at (.*) with all your might\!/i,
	"shield_trample"        => /You raise your (.*) before you and charge headlong towards (.*)\!/i,
	"shielded_brawler"      => /Shielded Brawler does not need to be activated once you have learned it.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization./i,
	"small_shield_focus"    => /Small Shield Focus does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
	"spell_block"           => /Spell Block does not need to be activated once you have learned it.  It will automatically apply to all relevant attacks, provided that you are wielding a shield and possess 3 ranks of the relevant Shield Focus specialization./i,
	"steady_shield"         => /Steady Shield does not need to be activated once you have learned it.  It will automatically apply to all relevant attacks against you, provided that you maintain the prerequisite ranks of Stun Maneuvers./i,
	"steely_resolve"        => /You focus your mind in a steely resolve to block all attacks against you.|You are still mentally fatigued from your last invocation of your Steely Resolve./i,
	"tortoise_stance"       => /You assume the Stance of the Tortoise, holding back some of your offensive power in order to maximize your defense.|You re\-settle into the Stance of the Tortoise, holding back your offensive power in order to maximize your defense./i,
	"tower_shield_focus"    => /Tower Shield Focus does not need to be activated.  If you are wielding the appropriate type of shield, it will always be active./i,
  }
  
  @@usage_hash = {
	"adamantine_bulwark"    => nil,
	"block_the_elements"    => nil,
	"deflect_magic"         => nil,
	"deflect_missiles"      => nil,
	"deflect_the_elements"  => nil,
	"disarming_presence"    => "dpresence",
	"guard_mastery"         => nil,
	"large_shield_focus"    => nil,
	"medium_shield_focus"   => nil,
	"phalanx"               => nil,
	"prop_up"               => nil,
	"protective_wall"       => nil,
	"shield_bash"           => "bash",
	"shield_charge"         => "charge",
	"shield_forward"        => "forward",
	"shield_mind"           => "mind",
	"shield_pin"            => "pin",
	"shield_push"           => "push",
	"shield_riposte"        => "riposte",
	"shield_spike_mastery"  => nil,
	"shield_strike"         => "strike",
	"shield_strike_mastery" => nil,
	"shield_swiftness"      => nil,
	"shield_throw"          => "throw",
	"shield_trample"        => "trample",
	"shielded_brawler"      => nil,
	"small_shield_focus"    => nil,
	"spell_block"           => nil,
	"steady_shield"         => nil,
	"steely_resolve"        => "resolve",
	"tortoise_stance"       => "tortoise",
	"tower_shield_focus"    => nil,
  }

  def Shield.method_missing(arg1, arg2=nil)
    echo "#{arg1} is not a defined Shield type.  Is it another Ability type?"
  end
  def Shield.[](name)
    Shield.send(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase)
  end
  def Shield.[]=(name,val)
    Shield.send("#{name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase}=", val.to_i)
  end

  def Shield.known?(name)
    Shield.send(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase) > 0
  end

  def Shield.affordable?(name)
    @@cost_hash.fetch(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase) < XMLData.stamina
  end

  def Shield.available?(name)
    Shield.known?(name) and Shield.affordable?(name) and
    !Lich::Util.normalize_lookup('Cooldowns', name) and !Lich::Util.normalize_lookup('Debuffs', 'Strained Muscles')
  end

  def Shield.use(name, target = "")
    return unless Shield.available?(name)
    usage = @@usage_hash.fetch(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase)
    return if usage.nil?
    dothistimeout("shield #{usage} #{target}", 3, @@regex_hash.fetch(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase))
  end

end
