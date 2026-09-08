{
  schema_version: 3,
  name: "dybbuk",
  noun: "dybbuk",
  url: "https://gswiki.play.net/dybbuk",
  picture: "",
  level: 48,
  family: "Chimeric",
  type: "Hybrid",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Corporeal undead",
    "Boss"
  ],
  bcs: true,
  max_hp: 400,
  speed: 12,
  height: 8,
  size: "large",
  areas: [
    {
      name: "Bonespear Tower",
      uids: [319100..319112, 319117..319133]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Length of Rusted Chain",
        as: (293..298)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (194..339),
    ranged: (158..259),
    bolt: (158..259),
    udf: (254..284),
    bar_td: (155..161),
    cle_td: (176..185),
    emp_td: (169..181),
    pal_td: (146..149),
    ran_td: (134..158),
    sor_td: (179..194),
    wiz_td: nil,
    mje_td: (195..196),
    mne_td: (195..196),
    mjs_td: 237,
    mns_td: 237,
    mnm_td: (144..147),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a length of rusted chain"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Glowing violet essence dust",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The dybbuk is a piecemeal composition of horror, its mismatched sections of body coalesced into a whole that would frighten a banshee. The thing lumbers, managing to look clumsy and menacing at the same time. The skin is pallid and stretched, and in places, gaping wounds reveal worse atrophy than that evident on the abomination's exterior. Huge hands grope before the dybbuk's trunk, sweeping around it in flailing arcs and leaving no doubt that close proximity to the creature spells dire results."
    ],
    arrival: [
      "A dybbuk shambles in!",
      "A dybbuk just arrived."
    ],
    flee: [
      "A dybbuk shambles {direction}.",
      "A dybbuk just went through an iron door."
    ],
    death: [
      "The dybbuk falls to the ground motionless.",
      "The dybbuk wails in terrifying pain one last time and lies still."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A dybbuk swings {weapon} at you!"
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
