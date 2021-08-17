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

end
