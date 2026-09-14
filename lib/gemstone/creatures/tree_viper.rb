{
  schema_version: 3,
  name: "tree viper",
  noun: "viper",
  url: "https://gswiki.play.net/tree_viper",
  picture: "",
  level: 24,
  family: "Reptilian",
  type: "Ophidian",
  undead: false,
  blood: true,
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
  max_hp: 212,
  speed: 9,
  height: 1,
  size: "medium",
  areas: [
    {
      name: "Karazja Jungle",
      uids: [5006004..5006009, 5006040..5006040]
    },
    {
      name: "Vipershroud",
      uids: [2190001..2190035]
    },
    {
      name: "unmapped",
      uids: [5006010..5006039]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (195..218)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Poisonous spit"
      },
      {
        name: "Spit"
      },
      {
        name: "Glob"
      },
      {
        name: "Lash"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (165..207),
    ranged: (140..197),
    bolt: (140..197),
    udf: (159..207),
    bar_td: nil,
    cle_td: (66..75),
    emp_td: (68..78),
    pal_td: (63..72),
    ran_td: 72,
    sor_td: (66..75),
    wiz_td: nil,
    mje_td: (72..75),
    mne_td: (72..75),
    mjs_td: (68..78),
    mns_td: (68..78),
    mnm_td: (72..75),
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
    skin: "tree viper fang",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The tree viper is a striking, brilliant green, complemented by its pale yellow underbelly that is usually only seen when the viper drapes over a tree branch. Much larger than a typical snake, the viper is nearly ten feet long, and it is quite capable of slaying foes as large as a human. The snake's lazy movement belies its ability to strike rapidly when threatened."
    ],
    arrival: [
      "A tree viper slithers in, hissing in warning!",
      "A tree viper slithers in."
    ],
    flee: [
      "A tree viper slithers {direction}.",
      "A tree viper drops from overhead and slithers {direction}.",
      "A tree viper darts up a tree and slithers through the canopy, heading {direction}."
    ],
    death: [
      "The tree viper twists and coils violently in its death throes, finally going still.",
      "The tree viper writhes in {pronoun} death throes, {pronoun} violent writhing causing {pronoun} to fall from {pronoun} perch."
    ],
    decay: [
      "A tree viper decays into a pile of scales and flesh."
    ],
    search: [],
    spell_prep: [
      "A tree viper hisses and bares {pronoun} fangs as {pronoun} coils defensively.",
      "A tree viper hisses loudly!"
    ],
    attacks: {
      bite: [
        "A tree viper's eyes glisten as it tries to bite you!"
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
