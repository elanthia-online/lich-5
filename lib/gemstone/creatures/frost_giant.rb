{
  schema_version: 3,
  name: "frost giant",
  noun: "giant",
  url: "https://gswiki.play.net/frost_giant",
  picture: "",
  level: 38,
  family: "Giant",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Element-based"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: 15,
  size: "huge",
  areas: [
    {
      name: "Glatoph",
      uids: [35026..35030, 35068..35072, 2153002..2153031]
    },
    {
      name: "Icemule Trail",
      uids: [4044001..4044019, 4044121..4044130]
    },
    {
      name: "Sleeping Lady Mountains",
      uids: [4560001..4560019]
    },
    {
      name: "Ice Plains",
      uids: [7502011..7502021]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "War hammer"
      },
      {
        name: "Battle axe",
        as: 251
      },
      {
        name: "Freezing ball of pure cold",
        as: 204
      },
      {
        name: "Frost-covered battle-axe",
        as: 244
      },
      {
        name: "Morning star",
        as: 216
      }
    ],
    bolt_spells: [
      {
        name: "Major Cold (907)",
        as: (177..222)
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Stomp"
      }
    ],
    special_abilities: [
      {
        name: "AS Boost"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (147..287),
    ranged: (125..201),
    bolt: (125..201),
    udf: (195..329),
    bar_td: 109,
    cle_td: (130..137),
    emp_td: (131..138),
    pal_td: (111..121),
    ran_td: (111..127),
    sor_td: (134..151),
    wiz_td: nil,
    mje_td: (145..151),
    mne_td: (145..151),
    mjs_td: (138..146),
    mns_td: (138..146),
    mnm_td: (117..126),
    defensive_spells: [
      "Spirit Defense (103)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a frost-covered battle axe",
    "a frost-covered battle-axe",
    "a fur-lined horned helm",
    "a horned helm",
    "a massive ice club",
    "a morning star",
    "an ice spear",
    "some brigandine armor"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a giant toe",
    other: "essence of water",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Standing more than twice as tall as the tallest giantman, the frost giant trails frost and snow in his wake. Seemingly carved from living ice and snow, icy blue eyes set beneath a heavily furrowed brow and a tangled mop of icy blue hair provide a splash of color against the frost giant's dull white frost-covered skin."
    ],
    arrival: [
      "A frost giant lumbers in, followed by a swirling snowstorm!"
    ],
    flee: [
      "A frost giant lumbers {direction}, followed by a swirling snowstorm."
    ],
    death: [
      "The frost giant cries out in cold agony one last time and dies.",
      "The frost giant falls to the ground motionless."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A frost giant mutters an incantation."
    ],
    stand: [
      "A frost giant throws {pronoun} head back and howls, shaking off the stun!"
    ],
    attacks: {
      attack: [
        "A frost giant swings {weapon} at you!"
      ],
      cast: [
        "A frost giant points an icy finger at you!"
      ],
      hurl: [
        "A frost giant hurls {weapon} at you!"
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
