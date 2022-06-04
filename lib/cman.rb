## breakout for CMan released with PSM3
## modifed code for 5.0.16
## includes new functions .known? and .affordable?

class CMan
  @@acrobats_leap          ||= 0
  @@bearhug                ||= 0
  @@berserk                ||= 0
  @@block_specialization   ||= 0
  @@bull_rush              ||= 0
  @@burst_of_swiftness     ||= 0
  @@cheapshots             ||= 0
  @@combat_focus           ||= 0
  @@combat_mobility        ||= 0
  @@combat_movement        ||= 0
  @@combat_toughness       ||= 0
  @@coup_de_grace          ||= 0
  @@crowd_press            ||= 0
  @@cunning_defense        ||= 0
  @@cutthroat              ||= 0
  @@dirtkick               ||= 0
  @@disarm_weapon          ||= 0
  @@dislodge               ||= 0
  @@divert                 ||= 0
  @@duck_and_weave         ||= 0
  @@dust_shroud            ||= 0
  @@evade_specialization   ||= 0
  @@eviscerate             ||= 0
  @@executioners_stance    ||= 0
  @@exsanguinate           ||= 0
  @@eyepoke                ||= 0
  @@feint                  ||= 0
  @@flurry_of_blows        ||= 0
  @@footstomp              ||= 0
  @@garrote                ||= 0
  @@grappel_specialization ||= 0
  @@griffins_voice         ||= 0
  @@groin_kick             ||= 0
  @@hamstring              ||= 0
  @@haymaker               ||= 0
  @@headbutt               ||= 0
  @@inner_harmony          ||= 0
  @@internal_power         ||= 0
  @@ki_focus               ||= 0
  @@kick_specialization    ||= 0
  @@kneebash               ||= 0
  @@leap_attack            ||= 0
  @@mighty_blow            ||= 0
  @@mug                    ||= 0
  @@nosetweak              ||= 0
  @@parry_specialization   ||= 0
  @@precision              ||= 0
  @@predators_eye          ||= 0
  @@punch_specialization   ||= 0
  @@retreat                ||= 0
  @@rolling_krynch_stance  ||= 0
  @@shield_bash            ||= 0
  @@side_by_side           ||= 0
  @@slippery_mind          ||= 0
  @@spell_cleave           ||= 0
  @@spell_parry            ||= 0
  @@spell_thieve           ||= 0
  @@spike_focus            ||= 0
  @@spin_attack            ||= 0
  @@staggering_blow        ||= 0
  @@stance_perfection      ||= 0
  @@stance_of_the_mongoose ||= 0
  @@striking_asp           ||= 0
  @@stun_maneuvers         ||= 0
  @@subdue                 ||= 0
  @@sucker_punch           ||= 0
  @@sunder_shield          ||= 0
  @@surge_of_strength      ||= 0
  @@sweep                  ||= 0
  @@swiftkick              ||= 0
  @@tackle                 ||= 0
  @@tainted_bond           ||= 0
  @@templeshot             ||= 0
  @@throatchop             ||= 0
  @@trip                   ||= 0
  @@true_strike            ||= 0
  @@unarmed_specialist     ||= 0
  @@vault_kick             ||= 0
  @@weapon_specialization  ||= 0
  @@whirling_dervish       ||= 0

  def CMan.acrobats_leap;                @@acrobats_leap;              end
  def CMan.bearhug;                      @@bearhug;                    end
  def CMan.berserk;                      @@berserk;                    end
  def CMan.block_specialization;         @@block_specialization;       end
  def CMan.bull_rush;                    @@bull_rush;                  end
  def CMan.burst_of_swiftness;           @@burst_of_swiftness;         end
  def CMan.cheapshots;                   @@cheapshots;                 end
  def CMan.combat_focus;                 @@combat_focus;               end
  def CMan.combat_mobility;              @@combat_mobility;            end
  def CMan.combat_movement;              @@combat_movement;            end
  def CMan.combat_toughness;             @@combat_toughness;           end
  def CMan.coup_de_grace;                @@coup_de_grace;              end
  def CMan.crowd_press;                  @@crowd_press;                end
  def CMan.cunning_defense;              @@cunning_defense;            end
  def CMan.cutthroat;                    @@cutthroat;                  end
  def CMan.dirtkick;                     @@dirtkick;                   end
  def CMan.disarm_weapon;                @@disarm_weapon;              end
  def CMan.dislodge;                     @@dislodge;                   end
  def CMan.divert;                       @@divert;                     end
  def CMan.duck_and_weave;               @@duck_and_weave;             end
  def CMan.dust_shroud;                  @@dust_shroud;                end
  def CMan.evade_specialization;         @@evade_specialization;       end
  def CMan.eviscerate;                   @@eviscerate;                 end
  def CMan.executioners_stance;          @@executioners_stance;        end
  def CMan.exsanguinate;                 @@exsanguinate;               end
  def CMan.eyepoke;                      @@eyepoke;                    end
  def CMan.feint;                        @@feint;                      end
  def CMan.flurry_of_blows;              @@flurry_of_blows;            end
  def CMan.footstomp;                    @@footstomp;                  end
  def CMan.garrote;                      @@garrote;                    end
  def CMan.grapple_specialization;       @@grapple_specialization;     end
  def CMan.griffins_voice;               @@griffins_voice;             end
  def CMan.groin_kick;                   @@groin_kick;                 end
  def CMan.hamstring;                    @@hamstring;                  end
  def CMan.haymaker;                     @@haymaker;                   end
  def CMan.headbutt;                     @@headbutt;                   end
  def CMan.inner_harmony;                @@inner_harmony;              end
  def CMan.internal_power;               @@internal_power;             end
  def CMan.ki_focus;                     @@ki_focus;                   end
  def CMan.kick_specialization;          @@kick_specialization;        end
  def CMan.kneebash;                     @@kneebash;                   end
  def CMan.leap_attack;                  @@leap_attack;                end
  def CMan.mighty_blow;                  @@mighty_blow;                end
  def CMan.mug;                          @@mug;                        end
  def CMan.nosetweak;                    @@nosetweak;                  end
  def CMan.parry_specialization;         @@parry_specialization;       end
  def CMan.precision;                    @@precision;                  end
  def CMan.predators_eye;                @@predators_eye;              end
  def CMan.punch_specialization;         @@punch_specialization;       end
  def CMan.retreat;                      @@retreat;                    end
  def CMan.rolling_krynch_stance;        @@rolling_krynch_stance;      end
  def CMan.shield_bash;                  @@shield_bash;                end
  def CMan.side_by_side;                 @@side_by_side;               end
  def CMan.slippery_mind;                @@slippery_mind;              end
  def CMan.spell_cleave;                 @@spell_cleave;               end
  def CMan.spell_parry;                  @@spell_parry;                end
  def CMan.spell_thieve;                 @@spell_thieve;               end
  def CMan.spike_focus;                  @@spike_focus;                end
  def CMan.spin_attack;                  @@spin_attack;                end
  def CMan.staggering_blow;              @@staggering_blow;            end
  def CMan.stance_perfection;            @@stance_perfection;          end
  def CMan.stance_of_the_mongoose;       @@stance_of_the_mongoose;     end
  def CMan.striking_asp;                 @@striking_asp;               end
  def CMan.stun_maneuvers;               @@stun_maneuvers;             end
  def CMan.subdue;                       @@subdue;                     end
  def CMan.sucker_punch;                 @@sucker_punch;               end
  def CMan.sunder_shield;                @@sunder_shield;              end
  def CMan.surge_of_strength;            @@surge_of_strength;          end
  def CMan.sweep;                        @@sweep;                      end
  def CMan.swiftkick;                    @@swiftkick;                  end
  def CMan.tackle;                       @@tackle;                     end
  def CMan.tainted_bond;                 @@tainted_bond;               end
  def CMan.templeshot;                   @@templeshot;                 end
  def CMan.throatchop;                   @@throatchop;                 end
  def CMan.trip;                         @@trip;                       end
  def CMan.true_strike;                  @@true_strike;                end
  def CMan.unarmed_specialist;           @@unarmed_specialist;         end
  def CMan.vault_kick;                   @@vault_kick;                 end
  def CMan.weapon_specialization;        @@weapon_specialization;      end
  def CMan.whirling_dervish;             @@whirling_dervish;           end

  def CMan.acrobats_leap=(val);          @@acrobats_leap=val;              end
  def CMan.bearhug=(val);                @@bearhug=val;                    end
  def CMan.berserk=(val);                @@berserk=val;                    end
  def CMan.block_specialization=(val);   @@block_specialization=val;       end
  def CMan.bull_rush=(val);              @@bull_rush=val;                  end
  def CMan.burst_of_swiftness=(val);     @@burst_of_swiftness=val;         end
  def CMan.cheapshots=(val);             @@cheapshots=val;                 end
  def CMan.combat_focus=(val);           @@combat_focus=val;               end
  def CMan.combat_mobility=(val);        @@combat_mobility=val;            end
  def CMan.combat_movement=(val);        @@combat_movement=val;            end
  def CMan.combat_toughness=(val);       @@combat_toughness=val;           end
  def CMan.coup_de_grace=(val);          @@coup_de_grace=val;              end
  def CMan.crowd_press=(val);            @@crowd_press=val;                end
  def CMan.cunning_defense=(val);        @@cunning_defense=val;            end
  def CMan.cutthroat=(val);              @@cutthroat=val;                  end
  def CMan.dirtkick=(val);               @@dirtkick=val;                   end
  def CMan.disarm_weapon=(val);          @@disarm_weapon=val;              end
  def CMan.dislodge=(val);               @@dislodge=val;                   end
  def CMan.divert=(val);                 @@divert=val;                     end
  def CMan.duck_and_weave=(val);         @@duck_and_weave=val;             end
  def CMan.dust_shroud=(val);            @@dust_shroud=val;                end
  def CMan.evade_specialization=(val);   @@evade_specialization=val;       end
  def CMan.eviscerate=(val);             @@eviscerate=val;                 end
  def CMan.executioners_stance=(val);    @@executioners_stance=val;        end
  def CMan.exsanguinate=(val);           @@exsanguinate=val;               end
  def CMan.eyepoke=(val);                @@eyepoke=val;                    end
  def CMan.feint=(val);                  @@feint=val;                      end
  def CMan.flurry_of_blows=(val);        @@flurry_of_blows=val;            end
  def CMan.footstomp=(val);              @@footstomp=val;                  end
  def CMan.garrote=(val);                @@garrote=val;                    end
  def CMan.grapple_specialization=(val); @@grapple_specialization=val;     end
  def CMan.griffins_voice=(val);         @@griffins_voice=val;             end
  def CMan.groin_kick=(val);             @@groin_kick=val;                 end
  def CMan.hamstring=(val);              @@hamstring=val;                  end
  def CMan.haymaker=(val);               @@haymaker=val;                   end
  def CMan.headbutt=(val);               @@headbutt=val;                   end
  def CMan.inner_harmony=(val);          @@inner_harmony=val;              end
  def CMan.internal_power=(val);         @@internal_power=val;             end
  def CMan.ki_focus=(val);               @@ki_focus=val;                   end
  def CMan.kick_specialization=(val);    @@kick_specialization=val;        end
  def CMan.kneebash=(val);               @@kneebash=val;                   end
  def CMan.leap_attack=(val);            @@leap_attack=val;                end
  def CMan.mighty_blow=(val);            @@mighty_blow=val;                end
  def CMan.mug=(val);                    @@mug=val;                        end
  def CMan.nosetweak=(val);              @@nosetweak=val;                  end
  def CMan.parry_specialization=(val);   @@parry_specialization=val;       end
  def CMan.precision=(val);              @@precision=val;                  end
  def CMan.predators_eye=(val);          @@predators_eye=val;              end
  def CMan.punch_specialization=(val);   @@punch_specialization=val;       end
  def CMan.retreat=(val);                @@retreat=val;                    end
  def CMan.rolling_krynch_stance=(val);  @@rolling_krynch_stance=val;      end
  def CMan.shield_bash=(val);            @@shield_bash=val;                end
  def CMan.side_by_side=(val);           @@side_by_side=val;               end
  def CMan.slippery_mind=(val);          @@slippery_mind=val;              end
  def CMan.spell_cleave=(val);           @@spell_cleave=val;               end
  def CMan.spell_parry=(val);            @@spell_parry=val;                end
  def CMan.spell_thieve=(val);           @@spell_thieve=val;               end
  def CMan.spike_focus=(val);            @@spike_focus=val;                end
  def CMan.spin_attack=(val);            @@spin_attack=val;                end
  def CMan.staggering_blow=(val);        @@staggering_blow=val;            end
  def CMan.stance_perfection=(val);      @@stance_perfection=val;          end
  def CMan.stance_of_the_mongoose=(val); @@stance_of_the_mongoose=val;     end
  def CMan.striking_asp=(val);           @@striking_asp=val;               end
  def CMan.stun_maneuvers=(val);         @@stun_maneuvers=val;             end
  def CMan.subdue=(val);                 @@subdue=val;                     end
  def CMan.sucker_punch=(val);           @@sucker_punch=val;               end
  def CMan.sunder_shield=(val);          @@sunder_shield=val;              end
  def CMan.surge_of_strength=(val);      @@surge_of_strength=val;          end
  def CMan.sweep=(val);                  @@sweep=val;                      end
  def CMan.swiftkick=(val);              @@swiftkick=val;                  end
  def CMan.tackle=(val);                 @@tackle=val;                     end
  def CMan.tainted_bond=(val);           @@tainted_bond=val;               end
  def CMan.templeshot=(val);             @@templeshot=val;                 end
  def CMan.throatchop=(val);             @@throatchop=val;                 end
  def CMan.trip=(val);                   @@trip=val;                       end
  def CMan.true_strike=(val);            @@true_strike=val;                end
  def CMan.unarmed_specialist=(val);     @@unarmed_specialist=val;         end
  def CMan.vault_kick=(val);             @@vault_kick=val;                 end
  def CMan.weapon_specialization=(val);  @@weapon_specialization=val;      end
  def CMan.whirling_dervish=(val);       @@whirling_dervish=val;           end

  @@cost_hash = { "acrobats_leap" => 0, "bearhug" => 10, "berserk" => 30, "block_specialization" => 0, "bull_rush" => 14, "burst_of_swiftness" => 30, "cheapshots" => 7, "combat_focus" => 0, "combat_mobility" => 0, "combat_movement" => 0, "combat_toughness" => 0, "coup_de_grace" => 20, "crowd_press" => 9, "cunning_defense" => 0, "cutthroat" => 14, "dirtkick" => 7, "disarm_weapon" => 7, "dislodge" => 9, "divert" => 7, "duck_and_weave" => 20, "dust_shroud" => 10, "evade_specialization" => 0, "eviscerate" => 14, "executioners_stance" => 20, "exsanguinate" => 15, "eyepoke" => 7, "feint" => 9, "flurry_of_blows" => 20, "footstomp" => 7, "garrote" => 10, "grapple_specialization" => 0, "griffins_voice" => 20, "groin_kick" => 7, "hamstring" => 9, "haymaker" => 9, "headbutt" => 9, "inner_harmony" => 20, "internal_power" => 20, "ki_focus" => 20, "kick_specialization" => 0, "kneebash" => 7, "leap_attack" => 15, "mighty_blow" => 15, "mug" => 15, "nosetweak" => 7, "parry_specialization" => 0, "precision" => 0, "predators_eye" => 20, "punch_specialization" => 0, "retreat" => 30, "rolling_krynch_stance" => 20, "shield_bash" => 9, "side_by_side" => 0, "slippery_mind" => 20, "spell_cleave" => 7, "spell_parry" => 0, "spell_thieve" => 7, "spike_focus" => 0, "spin_attack" => 15, "staggering_blow" => 15, "stance_perfection" => 0, "stance_of_the_mongoose" => 20, "striking_asp" => 20, "stun_maneuvers" => 10, "subdue" => 9, "sucker_punch" => 7, "sunder_shield" => 7, "surge_of_strength" => 30, "sweep" => 7, "swiftkick" => 7, "tackle" => 7, "tainted_bond" => 0, "templeshot" => 7, "throatchop" => 7, "trip" => 7, "true_strike" => 15, "unarmed_specialist" => 0, "vault_kick" => 30, "weapon_specialization" => 0, "whirling_dervish" => 20 }

  def CMan.method_missing(arg1, arg2=nil)
    echo "#{arg1} is not a defined CMan.  Was it moved to another Ability?"
  end
  def CMan.[](name)
    CMan.send(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase)
  end
  def CMan.[]=(name,val)
    CMan.send("#{name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase}=", val.to_i)
  end

  def CMan.known?(name)
    CMan.send(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase) > 0
  end

  def CMan.affordable?(name)
    @@cost_hash.fetch(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase) < XMLData.stamina
  end

  def CMan.available?(name)
    CMan.known?(name) and CMan.affordable?(name) and
    !Lich::Util.normalize_lookup('Cooldowns', name) and !Lich::Util.normalize_lookup('Debuffs', 'Overexerted')
  end

end
