{
  schema_version: 3,
  name: "lich qyn'arj",
  noun: "qyn'arj",
  url: "https://gswiki.play.net/lich_qyn'arj",
  picture: "",
  level: 84,
  family: "Reptilian",
  type: "Hybrid",
  undead: true,
  blood: false,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead",
    "Magical"
  ],
  bcs: true,
  max_hp: 262,
  speed: 8,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "Old Ta'Faendryl",
      uids: [17002201..17002247, 17002301..17002325]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (368..382)
      },
      {
        name: "Smash",
        as: 363
      }
    ],
    bolt_spells: [
      {
        name: "Minor Cold (1709)",
        as: 370
      },
      {
        name: "Web (118)",
        as: 351
      }
    ],
    warding_spells: [
      {
        name: "Unbalance (110)",
        cs: 341
      },
      {
        name: "Web (118)",
        cs: 341
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Gesture"
      },
      {
        name: "Ground Slam"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6",
    immunities: [],
    melee: (290..447),
    ranged: (283..331),
    bolt: (283..331),
    udf: (379..564),
    bar_td: (333..336),
    cle_td: (350..359),
    emp_td: 353,
    pal_td: nil,
    ran_td: (318..324),
    sor_td: (368..377),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 391,
    mjs_td: (353..359),
    mns_td: (353..359),
    mnm_td: (305..311),
    defensive_spells: [
      "Lesser Shroud",
      "Spirit Shield",
      "Spirit Warding II"
    ],
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
    boxes: nil,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The qyn'arj is a creature of legend, a massive serpent held aloft on brightly colored wings. But the lich qyn'arj before you has been animated by some means. The qyn'arj's body seems to hover there without the need to beat its rotting and mottled wings. Decaying flesh covers its body, but the head is completely skeletal and polished to the fine white of bleached bone. Swirling red pinpoints float where eyes used to be, and dagger sharp teeth can be seen inside its maw."
    ],
    arrival: [
      "A lich qyn'arj arrives on powerful strokes of its rotting wings.",
      "A lich qyn'arj floats in on rotting wings with a shrill cry!"
    ],
    flee: [],
    death: [
      "The lich qyn'arj spasms violently and suddenly goes still, its body turning to stone."
    ],
    decay: [
      "The stone form of a lich qyn'arj crumbles away to dust."
    ],
    search: [],
    spell_prep: [
      "A lich qyn'arj hisses a harsh guttural phrase.",
      "A lich qyn'arj glows brightly, unleashing a searing white beam at you!",
      "A lich qyn'arj gestures with rotting mottled wings at you!"
    ],
    attacks: {
      attack: [
        "A lich qyn'arj gestures with rotting mottled wings at you!",
        "A lich qyn'arj opens {pronoun} skeletal jaws wide and bares {pronoun} fangs at you!"
      ],
      bite: [
        "A lich qyn'arj tries to bite you!"
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
