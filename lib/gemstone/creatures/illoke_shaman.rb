{
  schema_version: 3,
  name: "Illoke shaman",
  noun: "shaman",
  url: "https://gswiki.play.net/illoke_shaman",
  picture: "",
  level: 67,
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
  speed: 9,
  height: 22,
  size: "huge",
  areas: [
    {
      name: "Stone Valley",
      uids: [4292017..4292060]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "War mattock"
      },
      {
        name: "Fist",
        as: 337
      },
      {
        name: "Foot",
        as: 303
      },
      {
        name: "Huge stone maul",
        as: 316
      },
      {
        name: "Massive granite hammer",
        as: (325..335)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Interdiction",
        cs: 282
      },
      {
        name: "Interference (212)",
        cs: 282
      },
      {
        name: "Huge stone maul",
        cs: 291
      }
    ],
    offensive_spells: [
      {
        name: "Earthen Fury"
      }
    ],
    maneuvers: [
      {
        name: "Divine Wrath"
      },
      {
        name: "Ground Slam"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16N",
    immunities: [],
    melee: (219..385),
    ranged: (164..286),
    bolt: (164..286),
    udf: (297..302),
    bar_td: (244..259),
    cle_td: (263..272),
    emp_td: (266..274),
    pal_td: (231..240),
    ran_td: (230..234),
    sor_td: (285..291),
    wiz_td: nil,
    mje_td: (300..306),
    mne_td: (300..306),
    mjs_td: (261..271),
    mns_td: (261..271),
    mnm_td: (218..227),
    defensive_spells: [
      "Benediction (307)",
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Elemental Targeting (425)",
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
    "a grey stone crescent symbol",
    "a huge stone maul",
    "a massive granite hammer",
    "a massive iron shield"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Glowing violet mote of essence",
      "essence of earth"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Massive and imposing, the Illoke shaman towers over adventurers. It is more than three times the size of the largest giantman, with smooth grey skin and deep black eyes that glare out from under a heavy brow. The eyes regard potential victims with disdain, as if they were nothing more than an offering to be sacrificed. Chiseled deep into the forehead of the shaman, the symbol of Illoke glows red with power."
    ],
    arrival: [
      "An Illoke shaman just came through an enormous arched doorway.",
      "An Illoke shaman rises out of the ground and shouts, \"Death to the invaders! You shall feel the cold grip of Illoke on your soft corpse!\""
    ],
    flee: [
      "An Illoke shaman sinks into the ground and flows {direction}."
    ],
    death: [
      "The Illoke shaman grumbles in pain one last time before lying still."
    ],
    decay: [
      "An Illoke shaman crumbles into a mass of shiny rocks, leaving nothing behind."
    ],
    search: [],
    spell_prep: [
      "An Illoke shaman mutters a prayer to {pronoun} god."
    ],
    stand: [
      "An Illoke shaman blinks dazedly a moment before shaking off the stun!"
    ],
    attacks: {
      attack: [
        "An Illoke shaman pounds at you with {pronoun} fist!",
        "An Illoke shaman stomps at you with {pronoun} foot!",
        "An Illoke shaman swings {weapon} at you!",
        "An Illoke shaman calls forth the wrath of {pronoun} god as {pronoun} points at you!"
      ],
      hurl: [
        "An Illoke shaman throws a large rock at you!",
        "An Illoke shaman throws a huge stone maul at you!",
        "An Illoke shaman throws a massive granite hammer at you!"
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
