## breakout for Weapon released with PSM3
## updated for Ruby 3.2.1 and new Infomon module

module Weapon
  # rubocop:disable Layout/ExtraSpacing
  def self.weapon_lookups
    [{ long_name: 'barrage',                 short_name: 'barrage',          cost: 15 },
     { long_name: 'charge',                  short_name: 'charge',           cost: 14 },
     { long_name: 'clash',			              short_name: 'clash',			      cost: 20 },
     { long_name: 'clobber',			            short_name: 'clobber',			    cost:  0 },
     { long_name: 'cripple',			            short_name: 'cripple',			    cost:  7 },
     { long_name: 'cyclone',			            short_name: 'cyclone',			    cost: 20 },
     { long_name: 'dizzying_swing',			    short_name: 'dizzyingswing',    cost: 7 },
     { long_name: 'flurry',			            short_name: 'flurry',			      cost: 15 },
     { long_name: 'fury',			              short_name: 'fury',			        cost: 15 },
     { long_name: 'guardant_thrusts',		    short_name: 'gthrusts',         cost: 15 },
     { long_name: 'overpower',			          short_name: 'overpower',        cost: 0 },
     { long_name: 'pin_down',                short_name: 'pindown',			    cost: 14 },
     { long_name: 'pulverize',               short_name: 'pulverize',			  cost: 20 },
     { long_name: 'pummel',			            short_name: 'pummel',           cost: 15 },
     { long_name: 'radial_sweep',			      short_name: 'radialsweep',      cost: 0 },
     { long_name: 'reactive_shot',           short_name: 'reactiveshot',     cost: 0 },
     { long_name: 'reverse_strike',          short_name: 'reversestrike',    cost: 0 },
     { long_name: 'riposte',			            short_name: 'riposte',          cost: 0 },
     { long_name: 'spin_kick',			          short_name: 'spinkick',         cost: 0 },
     { long_name: 'thrash',                  short_name: 'thrash',           cost: 15 },
     { long_name: 'twin_hammerfists',        short_name: 'twinhammer',       cost: 7 },
     { long_name: 'volley',			            short_name: 'volley',           cost: 20 },
     { long_name: 'whirling_blade',			    short_name: 'wblade',           cost: 20 },
     { long_name: 'whirlwind',               short_name: 'whirlwind',        cost: 20 }]
  end
  # rubocop:enable Layout/ExtraSpacing

  def Weapon.[](name)
    return PSM.assess(name, 'Weapon')
  end

  def Weapon.known?(name)
    return Weapon[name] > 0
  end

  def Weapon.affordable?(name)
    return PSM.affordable?(name, 'Weapon')
  end

  def Weapon.available?(name)
    Weapon.known?(name) and Weapon.affordable?(name) and
      !Lich::Util.normalize_lookup('Cooldowns', name) and !Lich::Util.normalize_lookup('Debuffs', 'Overexerted')
  end
end
