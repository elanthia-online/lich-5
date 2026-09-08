{
  schema_version: 3,
  name: "necrotic snake",
  noun: "snake",
  url: "https://gswiki.play.net/necrotic_snake",
  picture: "",
  level: 48,
  family: "Reptilian",
  type: "Ophidian",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 262,
  speed: 8,
  height: 1,
  size: "medium",
  areas: [
    {
      name: "Marsh Keep",
      uids: [376001..376001, 376003..376010, 376015..376018, 376020..376034, 376040..376044]
    },
    {
      name: "Fethayl Bog",
      uids: [13038001..13038031]
    },
    {
      name: "unmapped",
      uids: [376002..376002, 376019..376019, 376035..376039]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Strike",
        as: (254..288)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Constriction"
      },
      {
        name: "Poison Spit"
      },
      {
        name: "Spit"
      },
      {
        name: "Strike"
      },
      {
        name: "Glob"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (234..488),
    ranged: (270..314),
    bolt: (270..314),
    udf: (283..482),
    bar_td: 161,
    cle_td: (167..185),
    emp_td: (175..184),
    pal_td: (146..158),
    ran_td: 119,
    sor_td: (176..194),
    wiz_td: nil,
    mje_td: (196..202),
    mne_td: (196..202),
    mjs_td: (175..186),
    mns_td: (175..186),
    mnm_td: (144..153),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: true,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a snake fang",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The fearsome product of magical experimentation, the necrotic snake is larger than most men. Rotting scales cover the length of the undead reptile in a diamond pattern formed of various hues of brown, gold, and black. Large gashes in the snake's side reveal thin rib bones and the carcasses of previous meals, while leaking rancid fumes into the surrounding air."
    ],
    arrival: [
      "A necrotic snake slithers in.",
      "A necrotic snake arrives, slithering awkwardly in obvious pain."
    ],
    flee: [
      "A necrotic snake slithers {direction}, leaving a trail of rotting scales."
    ],
    death: [
      "A necrotic snake's tail trembles then falls to the ground as the rest of its body goes limp.",
      "A sinuous necrotic snake's tail trembles then falls to the ground as the rest of its body goes limp.",
      "A flexile necrotic snake's tail trembles then falls to the ground as the rest of its body goes limp."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A necrotic snake hisses and strikes at you!",
      "A necrotic snake hisses and whips {pronoun} tail violently against the ground."
    ],
    stun_break: [
      "A necrotic snake writhes wildly trying to regain {pronoun} bearings!"
    ],
    attacks: {
      attack: [
        "A necrotic snake hisses and strikes at you!"
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
