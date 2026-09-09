{
  schema_version: 3,
  name: "swirling spectre",
  noun: "spectre",
  url: "https://gswiki.play.net/swirling_spectre",
  picture: "",
  level: 37,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: true,
  max_hp: 240,
  speed: 10,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "Stormpeak",
      uids: [13150201..13150220]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 144
      },
      {
        name: "Ensnare",
        as: 222
      }
    ],
    bolt_spells: [
      {
        name: "Cone of Elements (518)",
        as: 150
      }
    ],
    warding_spells: [
      {
        name: "Thought Lash (1210)",
        cs: 140
      },
      {
        name: "Vertigo (1219)",
        cs: 140
      }
    ],
    offensive_spells: [
      {
        name: "Call Wind (912)"
      }
    ],
    maneuvers: [
      {
        name: "Claw"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "5N",
    immunities: [],
    melee: (70..212),
    ranged: (90..148),
    bolt: (90..148),
    udf: (115..244),
    bar_td: nil,
    cle_td: (129..136),
    emp_td: (134..143),
    pal_td: (108..118),
    ran_td: (106..114),
    sor_td: (139..145),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 147,
    mjs_td: 146,
    mns_td: 146,
    mnm_td: (118..127),
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Barrier (102)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)",
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Blink (1215)"
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
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Note: Creature description did not display"
    ],
    arrival: [
      "The wind manifests into a swirling spectre!"
    ],
    flee: [
      "A swirling spectre floats {direction}."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [
      "A swirling spectre gestures and utters a phrase of arcane magic."
    ],
    attacks: {
      attack: [
        "A swirling spectre tries to ensnare you!",
        "A swirling spectre points a wispy claw at you!"
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
