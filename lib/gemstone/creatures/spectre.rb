{
  schema_version: 3,
  name: "spectre",
  noun: "spectre",
  url: "https://gswiki.play.net/spectre",
  picture: "",
  level: 14,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 127,
  speed: nil,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "Vornavian Coast",
      uids: [4202161..4202180]
    },
    {
      name: "Wolves' Den",
      uids: [390002..390022, 390025..390048]
    },
    {
      name: "Plains of Bone",
      uids: [14011042..14011054]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Halberd",
        as: 102
      },
      {
        name: "Battle axe",
        as: 102
      },
      {
        name: "Fist",
        as: 102
      }
    ],
    bolt_spells: [
      {
        name: "Minor Shock (901)",
        as: 137
      },
      {
        name: "Major Cold (907)",
        as: 137
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Call Wind (912)"
      }
    ],
    maneuvers: [
      {
        name: "Gas cloud"
      },
      {
        name: "Mystic Gesture"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "17",
    immunities: [],
    melee: (49..156),
    ranged: (33..52),
    bolt: (33..52),
    udf: (71..167),
    bar_td: nil,
    cle_td: 42,
    emp_td: 42,
    pal_td: (39..42),
    ran_td: 42,
    sor_td: 42,
    wiz_td: nil,
    mje_td: 42,
    mne_td: 42,
    mjs_td: 42,
    mns_td: 42,
    mnm_td: 42,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a pitted battle axe",
    "a rusty metal breastplate",
    "a halberd",
    "some double leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a spectre's ",
    other: "Alchemy (common)",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [],
    arrival: [
      "A spectre just arrived.",
      "A shadowy spectre just arrived."
    ],
    flee: [
      "A luminous spectre floats {direction}."
    ],
    death: [
      "The spectre falls to the ground motionless.",
      "The shadowy spectre falls to the ground motionless."
    ],
    decay: [
      "A spectre turns to dust.",
      "A shadowy spectre turns to dust."
    ],
    search: [],
    spell_prep: [
      "A spectre hisses an evil incantation!",
      "A spectre utters a phrase of arcane magic.",
      "A spectre growls an evil incantation!"
    ],
    attacks: {
      attack: [
        "A spectre gestures at you!",
        "A spectre nods at you!",
        "A spectre pounds at you with {pronoun} fist!",
        "A spectre swings {weapon} at you!"
      ]
    },
    info: {
      general: [
        "Also encountered as an unarmed (\"monk\") variant at Plains of Bone, using natural attacks instead of weapons."
      ],
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
