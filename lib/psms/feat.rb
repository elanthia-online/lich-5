## breakout for Feat released with PSM3
## updated for Ruby 3.2.1 and new Infomon module

module Feat
  def self.feat_lookups
    [{ long_name: 'absorb_magic',              short_name: 'absorbmagic',        cost:  0 },
     { long_name: 'chain_armor_proficiency',   short_name: 'chainarmor',         cost:  0 },
     { long_name: 'combat_mastery',            short_name: 'combatmastery',      cost:  0 },
     { long_name: 'critical_counter',          short_name: 'criticalcounter',    cost:  0 },
     { long_name: 'dispel_magic',              short_name: 'dispelmagic',        cost: 30 },
     { long_name: 'dragonscale_skin',          short_name: 'dragonscaleskin',    cost:  0 },
     { long_name: 'guard',                     short_name: 'guard',              cost:  0 },
     { long_name: 'kroderine_soul',            short_name: 'kroderinesoul',      cost:  0 },
     { long_name: 'light_armor_proficiency',   short_name: 'lightarmor',         cost:  0 },
     { long_name: 'martial_arts_mastery',      short_name: 'martialarts',        cost:  0 },
     { long_name: 'martial_mastery',           short_name: 'martialmastery',     cost:  0 },
     { long_name: 'mental_acuity',             short_name: 'mentalacuity',       cost:  0 },
     { long_name: 'mystic_strike',             short_name: 'mysticstrike',       cost: 10 },
     { long_name: 'mystic_tattoo',             short_name: 'tattoo',             cost:  0 },
     { long_name: 'perfect_self',              short_name: 'perfectself',        cost:  0 },
     { long_name: 'plate_armor_proficiency',   short_name: 'platearmor',         cost:  0 },
     { long_name: 'protect',                   short_name: 'protect',            cost:  0 },
     { long_name: 'scale_armor_proficiency',   short_name: 'scalearmor',         cost:  0 },
     { long_name: 'shadow_dance',              short_name: 'shadowdance',        cost: 30 },
     { long_name: 'silent_strike',             short_name: 'silentstrike',       cost: 20 },
     { long_name: 'vanish',                    short_name: 'vanish',             cost: 30 },
     { long_name: 'weapon_bonding',            short_name: 'weaponbonding',      cost:  0 },
     { long_name: 'weighting',                 short_name: 'wps',                cost:  0 },
     { long_name: 'padding',                   short_name: 'wps',                cost:  0 }]
  end

  def Feat.[](name)
    return PSMS.assess(name, 'Feat')
  end

  def Feat.known?(name)
    Feat[name] > 0
  end

  def Feat.affordable?(name)
    return PSMS.assess(name, 'Feat', true)
  end

  def Feat.available?(name)
    Feat.known?(name) and Feat.affordable?(name) and !Lich::Util.normalize_lookup('Cooldowns', name) and !Lich::Util.normalize_lookup('Debuffs', 'Overexerted')
  end

  Feat.feat_lookups.each { |feat|
    self.define_singleton_method(feat[:short_name]) do
      Feat[feat[:short_name]]
    end

    self.define_singleton_method(feat[:long_name]) do
      Feat[feat[:short_name]]
    end
  }
end
