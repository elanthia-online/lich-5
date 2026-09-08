{
  schema_version: 3,
  name: "Illoke mystic",
  noun: "mystic",
  url: "https://gswiki.play.net/illoke_mystic",
  picture: "",
  level: 62,
  family: "Giant",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 600,
  speed: 8,
  height: 22,
  size: "huge",
  areas: [
    {
      name: "Stone Valley",
      uids: [4292001..4292050]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Giant stone hammer",
        as: 341
      },
      {
        name: "Heavy stone hammer",
        as: 255
      },
      {
        name: "Large rock",
        as: 356
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Divine Wrath"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16N",
    immunities: [],
    melee: (234..345),
    ranged: (99..165),
    bolt: (99..165),
    udf: (215..407),
    bar_td: (229..234),
    cle_td: (244..251),
    emp_td: (237..246),
    pal_td: (220..225),
    ran_td: (204..211),
    sor_td: (259..269),
    wiz_td: nil,
    mje_td: 273,
    mne_td: 273,
    mjs_td: 277,
    mns_td: 277,
    mnm_td: (200..210),
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Elemental Targeting (425)",
      "Natural Colors (601)",
      "Resist Elements (602)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a giant stone hammer",
    "a grey stone crescent symbol",
    "a heavy stone hammer",
    "a massive iron shield"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Glowing violet essence dust",
      "essence of earth"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Massive and imposing, the Illoke mystic towers over adventurers. It is more than three times the size of the largest giantman, with smooth grey skin and deep black eyes that glare out from under a heavy brow. The eyes regard potential victims with disdain, as if they were nothing more than an offering to be sacrificed. Chiseled deep into the forehead of the shaman, the symbol of Illoke glows red with power."
    ],
    arrival: [
      "An Illoke mystic just arrived.",
      "An Illoke mystic just came through an enormous arched doorway."
    ],
    flee: [
      "An Illoke mystic sinks into the ground and flows {direction}.",
      "An Illoke mystic just went through an enormous arched doorway.",
      "An Illoke mystic just went through a massive ora door."
    ],
    death: [
      "The Illoke mystic grumbles in pain one last time before lying still.",
      "The Illoke mystic shudders one last time before lying still."
    ],
    decay: [
      "An Illoke mystic crumbles into a mound of sand that quickly blows away."
    ],
    search: [],
    spell_prep: [],
    stand: [
      "An Illoke mystic blinks dazedly a moment before shaking off the stun!"
    ],
    attacks: {
      attack: [
        "An Illoke mystic swings {weapon} at you!",
        "An Illoke mystic summons the wrath of {pronoun} god as {pronoun} gestures at you!"
      ],
      hurl: [
        "An Illoke mystic throws {weapon} at you!"
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
