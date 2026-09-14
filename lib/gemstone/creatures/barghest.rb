{
  schema_version: 3,
  name: "barghest",
  noun: "barghest",
  url: "https://gswiki.play.net/barghest",
  picture: "",
  level: 35,
  family: "Canine",
  type: "Quadruped",
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
  max_hp: 262,
  speed: 7,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Yegharren Plains",
      uids: [13036201..13036217, 13036301..13036310, 13036401..13036414]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge (attack)",
        as: 229
      },
      {
        name: "Bite",
        as: (197..234)
      },
      {
        name: "Charge",
        as: (206..214)
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
    asg: "8N",
    immunities: [],
    melee: (129..250),
    ranged: (123..190),
    bolt: (123..190),
    udf: (160..272),
    bar_td: 109,
    cle_td: (121..130),
    emp_td: (121..130),
    pal_td: (96..105),
    ran_td: (99..108),
    sor_td: (122..128),
    wiz_td: nil,
    mje_td: (125..134),
    mne_td: (125..134),
    mjs_td: (146..155),
    mns_td: (146..155),
    mnm_td: (102..105),
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
    magic_items: false,
    gems: false,
    boxes: false,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The ghostly counterpart of her living canine brothers, the barghest shimmers like a growling mass of mist as she raises her spectral head in a piercing, mournful howl. The undead beast appears to be nearly transparent, but the blood and shreds of flesh on her slavering jaws suggest that she is capable of considerable corpoeral harm."
    ],
    arrival: [
      "A barghest pads in on ghostly quiet paws."
    ],
    flee: [
      "A barghest pads west in a ghostly silence.",
      "A barghest pads east in a ghostly silence.",
      "A barghest pads southeast in a ghostly silence.",
      "A barghest pads northwest in a ghostly silence.",
      "A barghest pads southwest in a ghostly silence.",
      "A barghest pads south in a ghostly silence.",
      "A barghest pads north in a ghostly silence.",
      "A barghest pads northeast in a ghostly silence.",
      "A barghest bounds forward while giving off a deep-throated howl."
    ],
    death: [
      "The barghest falls to the ground and dies.",
      "The barghest rolls over and dies."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A barghest charges at you!"
      ],
      bite: [
        "A barghest tries to bite you!"
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
