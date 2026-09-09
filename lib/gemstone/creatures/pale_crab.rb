{
  schema_version: 3,
  name: "pale crab",
  noun: "crab",
  url: "https://gswiki.play.net/pale_crab",
  picture: "",
  level: 2,
  family: "Crab",
  type: "Crustacean",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 36,
  speed: 12,
  height: 1,
  size: "small",
  areas: [
    {
      name: "Coastal Cliffs",
      uids: [2163601..2163628]
    },
    {
      name: "Vornavian Coast",
      uids: [4202401..4202416]
    },
    {
      name: "The Citadel",
      uids: [2103018..2103034]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 43
      },
      {
        name: "Ensnare",
        as: (23..53)
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
    asg: "1N",
    immunities: [],
    melee: (36..57),
    ranged: (34..54),
    bolt: 24,
    udf: 44,
    bar_td: 6,
    cle_td: 6,
    emp_td: 6,
    pal_td: (3..6),
    ran_td: 6,
    sor_td: 6,
    wiz_td: nil,
    mje_td: 6,
    mne_td: 6,
    mjs_td: (6..12),
    mns_td: (6..12),
    mnm_td: 6,
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
    magic_items: true,
    gems: true,
    boxes: false,
    skin: "pale crab pincer",
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The giant pale crab is about a foot across and has large pincers at the end of each of its two arms. Its multiple legs make a skittering noise as it walks. The pale color seems to be the result of living in dark, wet caves for its entire life."
    ],
    arrival: [],
    flee: [
      "The crab skitters {direction}."
    ],
    death: [
      "The pale crab falls back into a heap and dies.",
      "The pale crab hisses one last time and dies."
    ],
    decay: [
      "A pale crab decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A pale crab tries to ensnare you!"
      ],
      claw: [
        "A pale crab claws at you!"
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
