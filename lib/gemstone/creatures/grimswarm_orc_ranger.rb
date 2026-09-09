{
  schema_version: 3,
  name: "Grimswarm orc ranger",
  noun: "ranger",
  url: "https://gswiki.play.net/Grimswarm",
  picture: "",
  level: nil,
  family: "Orc",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: nil,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Grimswarm"
  ],
  bcs: true,
  max_hp: nil,
  speed: nil,
  height: nil,
  size: "",
  areas: [],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Mace",
        as: 231
      },
      {
        name: "Plain wooden arrow",
        as: (274..465)
      },
      {
        name: "Trident",
        as: 269
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Stomp"
      }
    ],
    special_abilities: [],
    special_notes: [
      "Grimswarm spawn in warcamps; level, AS/DS and TDs scale with the camp, so fixed values are not recorded.",
      "Wields conventional weapons."
    ]
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
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
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [],
    arrival: [
      "A Grimswarm orc ranger just arrived."
    ],
    flee: [
      "A Grimswarm orc ranger heads {direction}."
    ],
    death: [],
    decay: [
      "A Grimswarm orc ranger decays into compost."
    ],
    search: [],
    spell_prep: [
      "A Grimswarm orc ranger gestures and utters a phrase of magic."
    ],
    attacks: {
      attack: [
        "A Grimswarm orc ranger gestures at you!",
        "A Grimswarm orc ranger swings {weapon} at you!",
        "A Grimswarm orc ranger thrusts with a trident at you!",
        "A Grimswarm orc ranger tries to stomp on you, but misses!"
      ],
      fire: [
        "A Grimswarm orc ranger fires {weapon} at you!"
      ]
    },
    info: {
      general: [
        "Observed with trident (AS 269-350) and casting spiritual-circle spells (CS 213), camp level unknown."
      ],
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
