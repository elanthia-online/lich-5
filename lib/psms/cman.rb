## breakout for CMan released with PSM3
## updated for Ruby 3.2.1 and new Infomon module

module CMan
  def self.cman_lookups
    [{ long_name: 'acrobats_leap',           short_name: 'acrobatsleap',     cost:  0 },
     { long_name: 'bearhug',                 short_name: 'bearhug',          cost: 10 },
     { long_name: 'berserk',                 short_name: 'berserk',          cost: 20 },
     { long_name: 'block_specialization',    short_name: 'blockspec',        cost:  0 },
     { long_name: 'bull_rush',               short_name: 'bullrush',         cost: 14 },
     { long_name: 'burst_of_swiftness',      short_name: 'burst',            cost: 30 },
     { long_name: 'cheapshots',              short_name: 'cheapshots',       cost:  7 },
     { long_name: 'combat_focus',            short_name: 'focus',            cost:  0 },
     { long_name: 'combat_mobility',         short_name: 'mobility',         cost:  0 },
     { long_name: 'combat_movement',         short_name: 'cmovement',        cost:  0 },
     { long_name: 'combat_toughness',        short_name: 'toughness',        cost:  0 },
     { long_name: 'coup_de_grace',           short_name: 'coupdegrace',      cost: 20 },
     { long_name: 'crowd_press',             short_name: 'cpress',           cost:  9 },
     { long_name: 'cunning_defense',         short_name: 'cdefense',         cost:  0 },
     { long_name: 'cutthroat',               short_name: 'cutthroat',        cost: 14 },
     { long_name: 'dirtkick',                short_name: 'dirtkick',         cost:  7 },
     { long_name: 'disarm_weapon',           short_name: 'disarm',           cost:  7 },
     { long_name: 'dislodge',                short_name: 'dislodge',         cost:  7 },
     { long_name: 'divert',                  short_name: 'divert',           cost:  7 },
     { long_name: 'duck_and_weave',          short_name: 'duckandweave',     cost: 20 },
     { long_name: 'dust_shroud',             short_name: 'shroud',           cost: 10 },
     { long_name: 'evade_specialization',    short_name: 'evadespec',        cost: 0 },
     { long_name: 'eviscerate',              short_name: 'eviscerate',       cost: 14 },
     { long_name: 'executioners_stance',     short_name: 'executioner',      cost: 20 },
     { long_name: 'exsanguinate',            short_name: 'exsanguinate',     cost: 15 },
     { long_name: 'eyepoke',                 short_name: 'eyepoke',          cost:  7 },
     { long_name: 'feint',                   short_name: 'feint',            cost:  9 },
     { long_name: 'flurry_of_blows',         short_name: 'flurry',           cost: 20 },
     { long_name: 'footstomp',               short_name: 'footstomp',        cost: 7 },
     { long_name: 'garrote',                 short_name: 'garrote',          cost: 10 },
     { long_name: 'grappel_specialization',  short_name: 'grapplespec',      cost:  0 },
     { long_name: 'griffins_voice',          short_name: 'griffin',          cost: 20 },
     { long_name: 'groin_kick',              short_name: 'gkick',            cost:	7 },
     { long_name: 'hamstring',               short_name: 'hamstring',        cost:  9 },
     { long_name: 'haymaker',                short_name: 'haymaker',         cost:  9 },
     { long_name: 'headbutt',                short_name: 'headbutt',         cost:  9 },
     { long_name: 'inner_harmony',           short_name: 'iharmony',         cost: 20 },
     { long_name: 'internal_power',          short_name: 'ipower',           cost: 20 },
     { long_name: 'ki_focus',                short_name: 'kifocus',          cost: 20 },
     { long_name: 'kick_specialization',     short_name: 'kickspec',         cost:  0 },
     { long_name: 'kneebash',                short_name: 'kneebash',         cost:  7 },
     { long_name: 'leap_attack',             short_name: 'leapattack',       cost: 15 },
     { long_name: 'mighty_blow',             short_name: 'mblow',            cost: 15 },
     { long_name: 'mug',                     short_name: 'mug',              cost: 15 },
     { long_name: 'nosetweak',               short_name: 'nosetweak',        cost:  7 },
     { long_name: 'parry_specialization',    short_name: 'parryspec',        cost:  0 },
     { long_name: 'precision',               short_name: 'precision',        cost:  0 },
     { long_name: 'predators_eye',           short_name: 'predator',         cost: 20 },
     { long_name: 'punch_specialization',    short_name: 'punchspec',        cost:  0 },
     { long_name: 'retreat',                 short_name: 'retreat',          cost: 30 },
     { long_name: 'rolling_krynch_stance',   short_name: 'krynch',           cost: 20 },
     { long_name: 'shield_bash',             short_name: 'sbash',            cost:  9 },
     { long_name: 'side_by_side',            short_name: 'sidebyside',       cost:  0 },
     { long_name: 'slippery_mind',           short_name: 'slipperymind',     cost:  0 },
     { long_name: 'spell_cleave',            short_name: 'scleave',          cost:  7 },
     { long_name: 'spell_parry',             short_name: 'sparry',           cost:  0 },
     { long_name: 'spell_thieve',            short_name: 'sthieve',          cost:  7 },
     { long_name: 'spike_focus',             short_name: 'spikefocus',       cost:  0 },
     { long_name: 'spin_attack',             short_name: 'sattack',          cost:  0 },
     { long_name: 'staggering_blow',         short_name: 'sblow',            cost: 15 },
     { long_name: 'stance_perfection',       short_name: 'stance',           cost:  0 },
     { long_name: 'stance_of_the_mongoose',  short_name: 'mongoose',         cost: 20 },
     { long_name: 'striking_asp',            short_name: 'asp',              cost: 20 },
     { long_name: 'stun_maneuvers',          short_name: 'stunman',          cost: 10 },
     { long_name: 'subdue',                  short_name: 'subdue',           cost:  9 },
     { long_name: 'sucker_punch',            short_name: 'spunch',           cost:  7 },
     { long_name: 'sunder_shield',           short_name: 'sunder',           cost:  7 },
     { long_name: 'surge_of_strength',       short_name: 'surge',            cost: 30 },
     { long_name: 'sweep',                   short_name: 'sweep',            cost:  7 },
     { long_name: 'swiftkick',               short_name: 'swiftkick',        cost:  7 },
     { long_name: 'tackle',                  short_name: 'tackle',           cost:  7 },
     { long_name: 'tainted_bond',            short_name: 'tainted',          cost:  0 },
     { long_name: 'templeshot',              short_name: 'templeshot',       cost:  7 },
     { long_name: 'throatchop',              short_name: 'throatchop',       cost:  7 },
     { long_name: 'trip',                    short_name: 'trip',             cost:  7 },
     { long_name: 'true_strike',             short_name: 'truestrike',       cost: 15 },
     { long_name: 'unarmed_specialist',      short_name: 'unarmedspec',      cost:  0 },
     { long_name: 'vault_kick',              short_name: 'vaultkick',        cost: 30 },
     { long_name: 'weapon_specialization',   short_name: 'wspec',            cost:  0 },
     { long_name: 'whirling_dervish',        short_name: 'dervish',          cost: 20 }]
  end

  def CMan.[](name)
    return PSMS.assess(name, 'CMan')
  end

  def CMan.known?(name)
    CMan[name] > 0
  end

  def CMan.affordable?(name)
    return PSMS.assess(name, 'CMan', true)
  end

  def CMan.available?(name)
    CMan.known?(name) and CMan.affordable?(name) and !Lich::Util.normalize_lookup('Cooldowns', name) and !Lich::Util.normalize_lookup('Debuffs', 'Overexerted')
  end

  CMan.cman_lookups.each { |cman|
    self.define_singleton_method(cman[:short_name]) do
      CMan[cman[:short_name]]
    end

    self.define_singleton_method(cman[:long_name]) do
      CMan[cman[:short_name]]
    end
  }
end
