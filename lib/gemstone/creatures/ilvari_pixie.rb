{
  schema_version: 3,
  name: "Ilvari pixie",
  noun: "pixie",
  url: "https://gswiki.play.net/ilvari_pixie",
  picture: "",
  level: 74,
  family: "Fey",
  type: "Biped",
  undead: false,
  blood: false,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Magical"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: 3,
  size: "small",
  areas: [
    {
      name: "Red Forest",
      uids: [480231..480245, 17006231..17006245]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Giant bee stinger",
        as: 348
      }
    ],
    bolt_spells: [
      {
        name: "Major Acid (1710)",
        as: 352
      }
    ],
    warding_spells: [
      {
        name: "Pain (711)",
        cs: 339
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Dispel (417)"
      },
      {
        name: "Major Elemental Wave (435)"
      }
    ],
    maneuvers: [
      {
        name: "Point"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "5N",
    immunities: [],
    melee: 312,
    ranged: (291..305),
    bolt: (291..305),
    udf: 477,
    bar_td: nil,
    cle_td: (300..307),
    emp_td: (302..311),
    pal_td: (260..268),
    ran_td: 265,
    sor_td: (311..333),
    wiz_td: nil,
    mje_td: 337,
    mne_td: 337,
    mjs_td: (302..311),
    mns_td: (302..311),
    mnm_td: 236,
    defensive_spells: [
      "Arcane Barrier (1720)",
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Invisibility (916)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a giant bee stinger",
    "a leafy green tunic"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "This smallish humanoid sports a pair of expressive sparkling eyes, lightly tanned skin, and a wide grin from ear to ear. Cute is too kind of a word for this caricature of elven descent. A faintly shimmering golden aura surrounds him."
    ],
    arrival: [
      "An Ilvari pixie fades into view."
    ],
    flee: [
      "An Ilvari pixie limps {direction}."
    ],
    death: [
      "The Ilvari pixie's eyes grow dim as his lifeforce fades away."
    ],
    decay: [
      "The layer of bark on an Ilvari pixie hardens and absorbs the attack!  The bark crackles as it crumbles to dust.",
      "The layer of bark on an Ilvari pixie hardens and absorbs the magical energy!  The bark crackles as it crumbles to dust."
    ],
    search: [],
    spell_prep: [
      "An Ilvari pixie hands begin to glow."
    ],
    attacks: {
      attack: [
        "An Ilvari pixie points precisely at you!",
        "An Ilvari pixie thrusts with a giant bee stinger at you!",
        "An Ilvari pixie springs into view!"
      ],
      bolt: [
        "An Ilvari pixie hurls a bubbling ball of acid at you!"
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
