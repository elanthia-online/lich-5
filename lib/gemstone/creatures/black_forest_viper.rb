{
  schema_version: 3,
  name: "black forest viper",
  noun: "viper",
  url: "https://gswiki.play.net/black_forest_viper",
  picture: "",
  level: 59,
  family: "Reptilian",
  type: "Ophidian",
  undead: false,
  blood: nil,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 260,
  speed: 6,
  height: 1,
  size: "medium",
  areas: [
    {
      name: "Blighted Forest",
      uids: [13020001..13020051, 13020100..13020114]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 340
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Venomous spit"
      },
      {
        name: "Spit"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (273..387),
    ranged: (278..321),
    bolt: (278..321),
    udf: 333,
    bar_td: (200..206),
    cle_td: (229..235),
    emp_td: (220..232),
    pal_td: (199..202),
    ran_td: (181..196),
    sor_td: (234..246),
    wiz_td: 246,
    mje_td: 246,
    mne_td: 246,
    mjs_td: (220..232),
    mns_td: (220..232),
    mnm_td: (171..177),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "Dodging",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye",
    "a bruised right eye"
  ],
  treasure: {
    coins: true,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a viper fang",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The black forest viper is a shadowy charcoal grey, complemented by its paler grey underbelly. Small horned protrusions rise above each of the viper's eyes, giving the creature a devilish appearance. Much larger than a typical snake, the viper is nearly ten feet long, and it is quite capable of slaying foes as large as a human. The snake's lazy movement belies its ability to strike rapidly when threatened."
    ],
    arrival: [
      "A black forest viper slithers in with a sibilant warning!",
      "A black forest viper slithers in.",
      "A black forest viper slowly slithers in."
    ],
    flee: [
      "A black forest viper slithers {direction}.",
      "A black forest viper slowly slithers {direction}."
    ],
    death: [
      "The black forest viper twists and coils violently in its death throes, finally going still."
    ],
    decay: [
      "A black forest viper decays into a pile of scales and flesh."
    ],
    search: [],
    spell_prep: [
      "A black forest viper hisses and bares {pronoun} fangs as {pronoun} coils defensively.",
      "A black forest viper hisses loudly!",
      "A black forest viper hisses softly."
    ],
    attacks: {
      bite: [
        "A black forest viper's eyes glisten as it tries to bite you!"
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
