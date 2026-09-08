{
  schema_version: 3,
  name: "skeletal giant",
  noun: "giant",
  url: "https://gswiki.play.net/skeletal_giant",
  picture: "",
  level: 33,
  family: "Giant",
  type: "Biped",
  undead: true,
  blood: nil,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 380,
  speed: nil,
  height: 12,
  size: "large",
  areas: [
    {
      name: "Upper Trollfang",
      uids: [16065..16071]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound",
        as: 227
      },
      {
        name: "Fist",
        as: 227
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
    melee: (148..197),
    ranged: (168..202),
    bolt: (168..202),
    udf: (181..200),
    bar_td: nil,
    cle_td: 105,
    emp_td: 106,
    pal_td: (96..99),
    ran_td: 99,
    sor_td: 112,
    wiz_td: nil,
    mje_td: 117,
    mne_td: 117,
    mjs_td: 145,
    mns_td: 145,
    mnm_td: 99,
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
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a skeletal giant bone",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Once haughtily roaming the land of the living, this fearsome giant now mindlessly and unceasingly moves from place to place. The skeletal giant glares straight ahead, eyes like smoldering coals contrasting with the bleached white bone of its thick skull. Although its flesh is mostly a memory, the strong, heavy bones are still intact, and an unseen force keeps them connected, driven toward the destruction of all things living."
    ],
    arrival: [
      "A skeletal giant just arrived."
    ],
    flee: [
      "A skeletal giant runs {direction}."
    ],
    death: [
      "A skeletal giant falls to the ground in a clattering, motionless heap."
    ],
    decay: [
      "A skeletal giant turns to dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A skeletal giant pounds at you with {pronoun} fist!"
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
