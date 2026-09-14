{
  schema_version: 3,
  name: "roa'ter",
  noun: "roa'ter",
  url: "https://gswiki.play.net/roa'ter",
  picture: "",
  level: 41,
  family: "Worm",
  type: "Worm",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: "boss",
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 262,
  speed: 4,
  height: 3,
  size: "huge",
  areas: [
    {
      name: "Castle Varunar",
      uids: [4750006..4750029]
    },
    {
      name: "Darkstone Castle",
      uids: [42500..42521]
    },
    {
      name: "Vornavian Coast",
      uids: [4218101..4218121]
    },
    {
      name: "Czeroth Caverns",
      uids: [13007201..13007228]
    },
    {
      name: "The Hive",
      uids: [13041001..13041026]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge",
        as: 244
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Burrow"
      },
      {
        name: "Tail Slam"
      },
      {
        name: "Tail Swipe"
      },
      {
        name: "Charge"
      },
      {
        name: "Stomp"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (134..332),
    ranged: (130..208),
    bolt: (130..208),
    udf: 234,
    bar_td: nil,
    cle_td: (142..155),
    emp_td: (146..149),
    pal_td: (120..123),
    ran_td: (123..129),
    sor_td: (151..154),
    wiz_td: nil,
    mje_td: 165,
    mne_td: 165,
    mjs_td: (137..146),
    mns_td: (137..146),
    mnm_td: (123..132),
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
    gems: true,
    boxes: true,
    skin: "roa'ter skin",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "This massive worm is probably over twenty to thirty feet long, making it an easy target to hit, but having incomparable force and strength. Dark red in color, it seems to have no eyes, but its keen sense of smell quickly finds targets."
    ],
    arrival: [],
    flee: [
      "A roa'ter slithers {direction}.",
      "The roa'ter warily backs away."
    ],
    death: [
      "The roa'ter rolls over and dies."
    ],
    decay: [
      "A roa'ter decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A roa'ter charges at you!"
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
