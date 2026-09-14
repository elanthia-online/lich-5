{
  schema_version: 3,
  name: "wooly mammoth",
  noun: "mammoth",
  url: "https://gswiki.play.net/wooly_mammoth",
  picture: "",
  level: 52,
  family: "Elephantid",
  type: "Quadruped",
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
  max_hp: 400,
  speed: 19,
  height: 12,
  size: "huge",
  areas: [
    {
      name: "Great Mountain Aenatumgana",
      uids: [4561001..4561020]
    },
    {
      name: "Pinefar Forests",
      uids: [4563051..4563060]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Foot",
        as: 302
      },
      {
        name: "Impale",
        as: (266..336)
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
    melee: (205..344),
    ranged: (268..272),
    bolt: (257..272),
    udf: 303,
    bar_td: 167,
    cle_td: (183..192),
    emp_td: (178..184),
    pal_td: (150..156),
    ran_td: (156..165),
    sor_td: (193..199),
    wiz_td: nil,
    mje_td: 205,
    mne_td: 205,
    mjs_td: (172..187),
    mns_td: (172..187),
    mnm_td: (156..165),
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
    skin: "a mammoth tusk",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Very few creatures stand in the path of a wooly mammoth for long. This huge mammal is covered with long, thick, dark brown hair that protects him against freezing conditions. His flexible trunk is flanked by two heavy ivory tusks that curl up and back toward his wide, flapping ears. An angered wooly mammoth has been known to pick up a reckless adventurer and throw the hapless person out of sight."
    ],
    arrival: [
      "A wooly mammoth trumpets loudly announcing {pronoun} arrival as {pronoun} lumbers in!",
      "A wooly mammoth lumbers in!",
      "A wooly mammoth lumbers in, trumpeting in pain!"
    ],
    flee: [
      "A wooly mammoth lumbers {direction}.",
      "A wooly mammoth lumbers {direction}, trumpeting in pain.",
      "A wooly mammoth slowly lumbers {direction}, trumpeting in agony.",
      "A wooly mammoth slowly backs away, shaking {pronoun} enormous head."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A wooly mammoth stomps at you with {pronoun} foot!",
        "A wooly mammoth tries to impale you on {pronoun} tusks!"
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
