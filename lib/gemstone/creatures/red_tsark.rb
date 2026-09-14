{
  schema_version: 3,
  name: "red tsark",
  noun: "tsark",
  url: "https://gswiki.play.net/red_tsark",
  picture: "",
  level: 66,
  family: "Reptilian",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Living",
    "Element-based",
    "Boss"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: 4,
  size: "large",
  areas: [
    {
      name: "Eye of V'Tull",
      uids: [3051003..3051030, 3061001..3061038]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Leap"
      },
      {
        name: "Bite",
        as: 293
      },
      {
        name: "Claw",
        as: 347
      },
      {
        name: "Roaring ball of fire",
        as: 294
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (166..211),
    ranged: (162..214),
    bolt: (162..214),
    udf: (300..448),
    bar_td: 254,
    cle_td: 273,
    emp_td: (272..281),
    pal_td: (226..235),
    ran_td: (235..244),
    sor_td: (285..294),
    wiz_td: nil,
    mje_td: (298..309),
    mne_td: (298..309),
    mjs_td: (302..311),
    mns_td: (302..311),
    mnm_td: (219..228),
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
    skin: "a tsark skin",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Circling and pacing, the red tsark creeps closer, her eyes glowing red with fury. The scaled creature moves constantly, crouched on her powerful back legs like a tightly wound spring, ready to launch an attack at any opportunity. Small front legs are held poised in front of the reptile's chest, armed with formidable claws that could easily disembowel an unwary adversary. Smoke trails from the red tsark's nostrils, punctuated by flames each time she snorts a challenge."
    ],
    arrival: [],
    flee: [
      "A red tsark darts {direction}.",
      "A red tsark slowly trundles {direction}."
    ],
    death: [
      "The red tsark goes limp and {pronoun} falls over as the fire slowly fades from {pronoun} eyes."
    ],
    decay: [],
    search: [
      "A red tsark looks around apprehensively as {pronoun} takes a step back."
    ],
    spell_prep: [],
    stand: [
      "A red tsark's long tail swishes around as {pronoun} scrambles to {pronoun} feet."
    ],
    attacks: {
      attack: [
        "A red tsark opens {pronoun} mouth and spews liquid flames at you!"
      ],
      bite: [
        "A red tsark tries to bite you!"
      ],
      claw: [
        "A red tsark claws at you!"
      ],
      hurl: [
        "A red tsark hurls {weapon} at you!"
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
