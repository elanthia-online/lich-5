{
  schema_version: 3,
  name: "bog wraith",
  noun: "wraith",
  url: "https://gswiki.play.net/bog_wraith",
  picture: "",
  level: 41,
  family: "Wraith",
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
  max_hp: 238,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Miasmal Forest",
      uids: [5003021..5003027, 5003030..5003030, 5003032..5003032, 5003036..5003050]
    },
    {
      name: "unmapped",
      uids: [5003028..5003029, 5003031..5003031, 5003033..5003035]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 216
      },
      {
        name: "Ensnare",
        as: (94..239)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Ensnare",
        cs: 206
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Lash"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (187..270),
    ranged: (173..273),
    bolt: (173..273),
    udf: 196,
    bar_td: nil,
    cle_td: (160..170),
    emp_td: (166..176),
    pal_td: (140..150),
    ran_td: (143..150),
    sor_td: (173..183),
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: (166..176),
    mns_td: (166..176),
    mnm_td: (176..185),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye"
  ],
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
      "A haze of cloaked blackness and violet vapors, the bog wraith floats in the air just above the ground. Its violet eyes illuminate between a soft glow and an angry blazoned appearance. A pair of clawed hands extend from the middle of its being, abnormally tiny in comparison to the rest of its body."
    ],
    arrival: [
      "A bog wraith floats in with a purple haze trailing directly behind {pronoun}."
    ],
    flee: [
      "A bog wraith floats southwest leaving a purple haze in {pronoun} wake.",
      "A bog wraith floats north leaving a purple haze in {pronoun} wake.",
      "A bog wraith floats south leaving a purple haze in {pronoun} wake.",
      "A bog wraith floats northeast leaving a purple haze in {pronoun} wake.",
      "A bog wraith floats southeast leaving a purple haze in {pronoun} wake.",
      "A bog wraith floats down leaving a purple haze in {pronoun} wake.",
      "A bog wraith floats northwest leaving a purple haze in {pronoun} wake."
    ],
    death: [
      "A bog wraith's form dissipates into a purple haze."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A bog wraith flares up with a violet aura."
    ],
    attacks: {
      attack: [
        "A bog wraith tries to ensnare you!",
        "A bog wraith scratches {pronoun} clawed hand at you!"
      ],
      claw: [
        "A bog wraith claws at you!"
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
