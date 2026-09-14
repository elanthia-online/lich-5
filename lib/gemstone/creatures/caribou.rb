{
  schema_version: 3,
  name: "caribou",
  noun: "caribou",
  url: "https://gswiki.play.net/caribou",
  picture: "",
  level: 32,
  family: "Deer",
  type: "Quadruped",
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
  max_hp: 370,
  speed: 7,
  height: 5,
  size: "large",
  areas: [
    {
      name: "Pinefar Forests",
      uids: [4563001..4563021]
    },
    {
      name: "Sleeping Lady Mountains",
      uids: [4565004..4565014]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge",
        as: 238
      },
      {
        name: "Kick",
        as: 232
      },
      {
        name: "(quarantine-recovered)",
        as: 238
      },
      {
        name: "Antlers",
        as: 238
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
    melee: (165..229),
    ranged: (150..195),
    bolt: (150..195),
    udf: 250,
    bar_td: 96,
    cle_td: (89..98),
    emp_td: (91..102),
    pal_td: (96..105),
    ran_td: (93..99),
    sor_td: (95..113),
    wiz_td: nil,
    mje_td: (100..110),
    mne_td: (100..110),
    mjs_td: (99..108),
    mns_td: (99..108),
    mnm_td: (96..99),
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
    skin: "a pair of caribou antlers",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A hoofed herbivore of the northern snowfields, the caribou is very similar to a large deer with a bad attitude. The caribou uses her large rack of antlers to eagerly impale anything that would encroach upon her territory. Light brown hide affords the caribou some camouflage against the more barren slopes, but the caribou relies on her defenses and running in herds to handle most predators."
    ],
    arrival: [
      "A caribou lopes into the area!"
    ],
    flee: [
      "A caribou lopes {direction}.",
      "A caribou lopes {direction}, shuddering in pain.",
      "A caribou lopes {direction}, shuddering in pain!",
      "The caribou slowly backs away and lowers {pronoun} antlers."
    ],
    death: [],
    decay: [],
    search: [
      "A caribou snuffles the ground hungrily."
    ],
    spell_prep: [],
    attacks: {
      attack: [
        "A caribou charges you with {pronoun} antlers!",
        "A caribou rears back and kicks {pronoun} front hooves at you!",
        "A caribou charges {target} with {pronoun} antlers!"
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
