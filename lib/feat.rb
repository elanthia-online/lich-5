## breakout for Feat released with PSM3
## new code for 5.0.16
## includes new functions .known? and .affordable?

class Feat
  @@absorb_magic                  ||= 0
  @@chain_armor_proficiency       ||= 0
  @@combat_mastery                ||= 0
  @@critical_counter              ||= 0
  @@dispel_magic                  ||= 0
  @@dragonscale_skin              ||= 0
  @@guard                         ||= 0
  @@kroderine_soul                ||= 0
  @@light_armor_proficiency       ||= 0
  @@martial_arts_mastery          ||= 0
  @@martial_mastery               ||= 0
  @@mental_acuity                 ||= 0
  @@mystic_strike                 ||= 0
  @@mystic_tattoo                 ||= 0
  @@perfect_self                  ||= 0
  @@plate_armor_proficiency       ||= 0
  @@protect                       ||= 0
  @@scale_armor_proficiency       ||= 0
  @@shadow_dance                  ||= 0
  @@silent_strike                 ||= 0
  @@vanish                        ||= 0
  @@weapon_bonding                ||= 0

  def Feat.absorb_magic;              @@absorb_magic;             end
  def Feat.chain_armor_proficiency;   @@chain_armor_proficiency;  end
  def Feat.combat_mastery;            @@combat_mastery;           end
  def Feat.critical_counter;          @@critical_counter;         end
  def Feat.dispel_magic;              @@dispel_magic;             end
  def Feat.dragonscale_skin;          @@dragonscale_skin;         end
  def Feat.guard;                     @@guard;                    end
  def Feat.kroderine_soul;            @@kroderine_soul;           end
  def Feat.light_armor_proficiency;   @@light_armor_proficiency;  end
  def Feat.martial_arts_mastery;      @@martial_arts_mastery;     end
  def Feat.martial_mastery;           @@martial_mastery;          end
  def Feat.mental_acuity;             @@mental_acuity;            end
  def Feat.mystic_strike;             @@mystic_strike;            end
  def Feat.mystic_tattoo;             @@mystic_tattoo;            end
  def Feat.perfect_self;              @@perfect_self;             end
  def Feat.plate_armor_proficiency;   @@plate_armor_proficiency;  end
  def Feat.protect;                   @@protect;                  end
  def Feat.scale_armor_proficiency;   @@scale_armor_proficiency;  end
  def Feat.shadow_dance;              @@shadow_dance;             end
  def Feat.silent_strike;             @@silent_strike;            end
  def Feat.vanish;                    @@vanish;                   end
  def Feat.weapon_bonding;            @@weapon_bonding;           end

  def Feat.absorb_magic=(val);              @@absorb_magic=val;             end
  def Feat.chain_armor_proficiency=(val);   @@chain_armor_proficiency=val;  end
  def Feat.combat_mastery=(val);            @@combat_mastery=val;           end
  def Feat.critical_counter=(val);          @@critical_counter=val;         end
  def Feat.dispel_magic=(val);              @@dispel_magic=val;             end
  def Feat.dragonscale_skin=(val);          @@dragonscale_skin=val;         end
  def Feat.guard=(val);                     @@guard=val;                    end
  def Feat.kroderine_soul=(val);            @@kroderine_soul=val;           end
  def Feat.light_armor_proficiency=(val);   @@light_armor_proficiency=val;  end
  def Feat.martial_arts_mastery=(val);      @@martial_arts_mastery=val;     end
  def Feat.martial_mastery=(val);           @@martial_mastery=val;          end
  def Feat.mental_acuity=(val);             @@mental_acuity=val;            end
  def Feat.mystic_strike=(val);             @@mystic_strike=val;            end
  def Feat.mystic_tattoo=(val);             @@mystic_tattoo=val;            end
  def Feat.perfect_self=(val);              @@perfect_self=val;             end
  def Feat.plate_armor_proficiency=(val);   @@plate_armor_proficiency=val;  end
  def Feat.protect=(val);                   @@protect=val;                  end
  def Feat.scale_armor_proficiency=(val);   @@scale_armor_proficiency=val;  end
  def Feat.shadow_dance=(val);              @@shadow_dance=val;             end
  def Feat.silent_strike=(val);             @@silent_strike=val;            end
  def Feat.vanish=(val);                    @@vanish=val;                   end
  def Feat.weapon_bonding=(val);            @@weapon_bonding=val;           end

  @@cost_hash = {
    "absorb_magic" => 0,
    "chain_armor_proficiency" => 0,
    "combat_mastery" => 0,
    "critical_counter" => 0,
    "dispel_magic" => 30,
    "dragonscale_skin" => 0,
    "guard" => 0,
    "kroderine_soul" => 0,
    "light_armor_proficiency" => 0,
    "martial_arts_mastery" => 0,
    "martial_mastery" => 0,
    "mental_acuity" => 0,
    "mystic_strike" => 10,
    "mystic_tattoo" => 0,
    "perfect_self" => 0,
    "plate_armor_proficiency" => 0,
    "protect" => 0,
    "scale_armor_proficiency" => 0,
    "shadow_dance" => 30,
    "silent_strike" => 20,
    "vanish" => 30,
    "weapon_bonding" => 0
  }

  def Feat.method_missing(arg1, arg2=nil)
    echo "#{arg1} is not a defined Feat type.  Is it another Ability type?"
  end
  def Feat.[](name)
    Feat.send(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase)
  end
  def Feat.[]=(name,val)
    Feat.send("#{name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase}=", val.to_i)
  end

  def Feat.known?(name)
    Feat.send(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase) > 0
  end

  def Feat.affordable?(name)
    @@cost_hash.fetch(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase) < XMLData.stamina
  end

  def Feat.available?(name)
    Feat.known?(name) and Feat.affordable?(name) and
    !Lich::Util.normalize_lookup('Cooldowns', name) and !Lich::Util.normalize_lookup('Debuffs', 'Overexerted')
  end

end
