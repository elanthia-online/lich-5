{
  schema_version: 3,
  name: "wind witch",
  noun: "witch",
  url: "https://gswiki.play.net/wind_witch",
  picture: "",
  level: 16,
  family: "Witch",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Element-based"
  ],
  bcs: true,
  max_hp: 142,
  speed: 6,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Stormpeak",
      uids: [13150001..13150016, 13150101..13150120]
    },
    {
      name: "Vornavian Coast",
      uids: [4214201..4214218]
    },
    {
      name: "Northern Slopes of Wehntoph",
      uids: [4302001..4302035]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Dagger",
        as: 161
      },
      {
        name: "Knife",
        as: 161
      }
    ],
    bolt_spells: [
      {
        name: "Minor Shock (901)",
        as: 139
      },
      {
        name: "Major Shock (910)",
        as: 139
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Call Wind (912)"
      }
    ],
    maneuvers: [
      {
        name: "Gas cloud"
      },
      {
        name: "Point"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "2",
    immunities: [],
    melee: (115..150),
    ranged: (98..133),
    bolt: (98..133),
    udf: (130..149),
    bar_td: (54..59),
    cle_td: (46..53),
    emp_td: (46..53),
    pal_td: (43..53),
    ran_td: (46..51),
    sor_td: (45..55),
    wiz_td: nil,
    mje_td: (44..59),
    mne_td: (44..59),
    mjs_td: 76,
    mns_td: 76,
    mnm_td: (48..55),
    defensive_spells: [
      "Elemental Defense I",
      "Elemental Defense II",
      "Thurfel's Ward (503)"
    ],
    defensive_abilities: [],
    special_defenses: [
      "Shake off stuns"
    ]
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bolt-etched bone knife",
    "a long knife",
    "a razor-sharp wavy dagger",
    "some flowing robes"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a crooked witch nose",
    other: [
      "essence of air",
      "s'ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Standing in the center of a swirling whorl of wind, the wind witch cackles evilly. Dull grey eyes stare out at you from under an unruly mop of tangled grey hair. The wind witch's bluish skin stands out against the tattered robes it wears."
    ],
    arrival: [],
    flee: [
      "A wind witch glides {direction}."
    ],
    death: [
      "The wind witch howls in agony one last time and dies.",
      "A wind witch dissipates into the air, leaving nothing behind.",
      "The wind witch crumples to the ground motionless."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    stun_break: [
      "A wind witch cackles madly, shaking off the stun!"
    ],
    attacks: {
      claw: [
        "A wind witch claws at your eyes unmercifully!"
      ],
      attack: [
        "A wind witch points {pronoun} outstretched hands at you!",
        "A wind witch swings {weapon} at you!"
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
