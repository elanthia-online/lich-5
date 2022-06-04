## breakout for Weapon released with PSM3
## new code for 5.0.16
## includes new functions .known? and .affordable?

class Weapon
  @@barrage                  ||=0
  @@charge                   ||=0
  @@clash                    ||=0
  @@clobber                  ||=0
  @@cripple                  ||=0
  @@cyclone                  ||=0
  @@dizzying_swing           ||=0
  @@flurry                   ||=0
  @@fury                     ||=0
  @@guardant_thrusts         ||=0
  @@overpower                ||=0
  @@pin_down                 ||=0
  @@pulverize                ||=0
  @@pummel                   ||=0
  @@radial_sweep             ||=0
  @@reactive_shot            ||=0
  @@reverse_strike           ||=0
  @@riposte                  ||=0
  @@spin_kick                ||=0
  @@thrash                   ||=0
  @@twin_hammerfists         ||=0
  @@volley                   ||=0
  @@whirling_blade           ||=0
  @@whirlwind                ||=0

  def Weapon.barrage;           @@barrage;              end
  def Weapon.charge;            @@charge;               end
  def Weapon.clash;             @@clash;                end
  def Weapon.clobber;           @@clobber;              end
  def Weapon.cripple;           @@cripple;              end
  def Weapon.cyclone;           @@cyclone;              end
  def Weapon.dizzying_swing;    @@dizzying_swing;       end
  def Weapon.flurry;            @@flurry;               end
  def Weapon.fury;              @@fury;                 end
  def Weapon.guardant_thrusts;  @@guardant_thrusts;     end
  def Weapon.overpower;         @@overpower;            end
  def Weapon.pin_down;          @@pin_down;             end
  def Weapon.pulverize;         @@pulverize;            end
  def Weapon.pummel;            @@pummel;               end
  def Weapon.radial_sweep;      @@radial_sweep;         end
  def Weapon.reactive_shot;     @@reactive_shot;        end
  def Weapon.reverse_strike;    @@reverse_strike;       end
  def Weapon.riposte;           @@riposte;              end
  def Weapon.spin_kick;         @@spin_kick;            end
  def Weapon.thrash;            @@thrash;               end
  def Weapon.twin_hammerfists;  @@twin_hammerfists;     end
  def Weapon.volley;            @@volley;               end
  def Weapon.whirling_blade;    @@whirling_blade;       end
  def Weapon.whirlwind;         @@whirlwind;            end

  def Weapon.barrage=(val);             @@barrage=val;              end
  def Weapon.charge=(val);              @@charge=val;               end
  def Weapon.clash=(val);               @@clash=val;                end
  def Weapon.clobber=(val);             @@clobber=val;              end
  def Weapon.cripple=(val);             @@cripple=val;              end
  def Weapon.cyclone=(val);             @@cyclone=val;              end
  def Weapon.dizzying_swing=(val);      @@dizzying_swing=val;       end
  def Weapon.flurry=(val);              @@flurry=val;               end
  def Weapon.fury=(val);                @@fury=val;                 end
  def Weapon.guardant_thrusts=(val);    @@guardant_thrusts=val;     end
  def Weapon.overpower=(val);           @@overpower=val;            end
  def Weapon.pin_down=(val);            @@pin_down=val;             end
  def Weapon.pulverize=(val);           @@pulverize=val;            end
  def Weapon.pummel=(val);              @@pummel=val;               end
  def Weapon.radial_sweep=(val);        @@radial_sweep=val;         end
  def Weapon.reactive_shot=(val);       @@reactive_shot=val;        end
  def Weapon.reverse_strike=(val);      @@reverse_strike=val;       end
  def Weapon.riposte=(val);             @@riposte=val;              end
  def Weapon.spin_kick=(val);           @@spin_kick=val;            end
  def Weapon.thrash=(val);              @@thrash=val;               end
  def Weapon.twin_hammerfists=(val);    @@twin_hammerfists=val;     end
  def Weapon.volley=(val);              @@volley=val;               end
  def Weapon.whirling_blade=(val);      @@whirling_blade=val;       end
  def Weapon.whirlwind=(val);           @@whirlwind=val;            end


  @@cost_hash = { "barrage" => 15, "charge" => 14, "clash" => 20, "clobber" => 0, "cripple" => 7, "cyclone" => 20, "dizzying_swing" => 7, "flurry" => 15, "fury" => 15, "guardant_thrusts" => 15, "overpower" => 0, "pin_down" => 14, "pulverize" => 20, "pummel" => 15, "radial_sweep" => 0, "reactive_shot" => 0, "reverse_strike" => 0, "riposte" => 0, "spin_kick" => 0, "thrash" => 15, "twin_hammerfists" => 7, "volley" => 20, "whirling_blade" => 20, "whirlwind" => 20 }

  def Weapon.method_missing(arg1, arg2=nil)
    echo "#{arg1} is not a defined Weapon type.  Is it another Ability type?"
  end
  def Weapon.[](name)
    Weapon.send(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase)
  end
  def Weapon.[]=(name,val)
    Weapon.send("#{name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase}=", val.to_i)
  end

  def Weapon.known?(name)
    Weapon.send(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase) > 0
  end

  def Weapon.affordable?(name)
    @@cost_hash.fetch(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase) < XMLData.stamina
  end

  def Weapon.available?(name)
    Weapon.known?(name) and Weapon.affordable?(name) and
    !Lich::Util.normalize_lookup('Cooldowns', name) and !Lich::Util.normalize_lookup('Debuffs', 'Overexerted')
  end

end
