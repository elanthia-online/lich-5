{
  schema_version: 3,
  name: "centaur",
  noun: "centaur",
  url: "https://gswiki.play.net/centaur",
  picture: "",
  level: 23,
  family: "Centaur",
  type: "Hybrid",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 265,
  speed: 10,
  height: 7,
  size: "large",
  areas: [
    {
      name: "Rambling Meadows",
      uids: [14006041..14006046, 14006048..14006060]
    },
    {
      name: "Vornavian Coast",
      uids: [4218101..4218121]
    },
    {
      name: "Locksmehr Trail",
      uids: [13001043..13001079]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Longsword",
        as: 208
      },
      {
        name: "Greatsword",
        as: 208
      },
      {
        name: "Scimitar",
        as: 166
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Kick"
      },
      {
        name: "Bull Rush"
      },
      {
        name: "Charge"
      },
      {
        name: "Tail Swipe"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "10",
    immunities: [],
    melee: (113..233),
    ranged: (80..197),
    bolt: (80..197),
    udf: (131..251),
    bar_td: (69..75),
    cle_td: (66..75),
    emp_td: (69..77),
    pal_td: (66..75),
    ran_td: (66..75),
    sor_td: (66..75),
    wiz_td: nil,
    mje_td: (63..72),
    mne_td: (63..72),
    mjs_td: 162,
    mns_td: 162,
    mnm_td: (66..75),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye",
    "a bruised right eye",
    "a greatsword",
    "a leather breastplate",
    "a polished longsword",
    "a steel-bossed buckler",
    "some hardened cuirbouilli leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a centaur hide",
    other: "Glimmering blue essence shard",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Seeming to be a blend of mannish torso upon the body of a light horse, the centaur has a certain charm and aura of mystery. That is, until you encounter one, for the centaur is a savage and wilder cousin to the great centaurs of legend and will lash out in terrible fury when it deems a threat is at hand. Their hide which varies in color from tan, black, white or roan is valued for its toughness and durability and thus, many will brave the danger of flying hooves and the threat held by these fierce creatures to gain this prize."
    ],
    arrival: [],
    flee: [
      "A black centaur gallops {direction}.",
      "A tan centaur gallops {direction}.",
      "A white centaur gallops {direction}.",
      "A roan centaur gallops {direction}.",
      "A bay centaur gallops {direction}."
    ],
    death: [
      "The white centaur falls to the ground and dies.",
      "The white centaur screams one last time and dies.",
      "The bay centaur falls to the ground and dies.",
      "The tan centaur screams one last time and dies.",
      "The roan centaur falls to the ground and dies.",
      "The bay centaur screams one last time and dies.",
      "The black centaur falls to the ground and dies.",
      "The tan centaur falls to the ground and dies.",
      "The roan centaur screams one last time and dies.",
      "The black centaur screams one last time and dies."
    ],
    decay: [
      "A white centaur dissolves into a puff of red smoke.",
      "A bay centaur dissolves into a puff of red smoke.",
      "A tan centaur dissolves into a puff of red smoke.",
      "A roan centaur dissolves into a puff of red smoke.",
      "A black centaur dissolves into a puff of red smoke.",
      "The thick skin of a minotaur warrior falls in upon itself as his enormous form decays into a fine dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A centaur swings {weapon} at you!",
        "Tightening {pronoun} grip on {pronoun} greatsword, a black {pronoun} strikes out at you with all of {pronoun} might!",
        "Tightening {pronoun} grip on {pronoun} polished longsword, a tan {pronoun} strikes out at you with all of {pronoun} might!",
        "Tightening {pronoun} grip on {pronoun} polished longsword, a white {pronoun} strikes out at you with all of {pronoun} might!"
      ],
      hurl: [
        "A centaur throws {weapon} at you!"
      ]
    },
    info: {
      general: [],
      class_tips: {
        cleric: [],
        paladin: [],
        ranger: [],
        bard: [],
        wizard: [],
        empath: [],
        rogue: [],
        warrior: [],
        sorcerer: []
      },
      miscellany: []
    },
    triggers: {}
  }
}
