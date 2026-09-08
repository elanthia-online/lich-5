{
  schema_version: 3,
  name: "stone mastiff",
  noun: "mastiff",
  url: "https://gswiki.play.net/stone_mastiff",
  picture: "",
  level: 62,
  family: "Canine",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: false,
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
  max_hp: 400,
  speed: 8,
  height: 4,
  size: "large",
  areas: [
    {
      name: "Stone Valley",
      uids: [4292001..4292060]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (229..268)
      },
      {
        name: "Claw",
        as: 337
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Charge"
      },
      {
        name: "Leap"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "20N",
    immunities: [],
    melee: (173..294),
    ranged: (151..242),
    bolt: (151..242),
    udf: (341..456),
    bar_td: (206..227),
    cle_td: (236..245),
    emp_td: (236..245),
    pal_td: (198..207),
    ran_td: (201..210),
    sor_td: (247..259),
    wiz_td: nil,
    mje_td: (260..274),
    mne_td: (260..274),
    mjs_td: 268,
    mns_td: 268,
    mnm_td: 186,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye",
    "a bruised right eye"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "a stone heart",
    other: "essence of earth",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The stone mastiff is a huge grey dog that seems to be formed of living stone. The mastiff is rectangular in shape, and the length of the mastiff from forechest to rear is around five feet. Massive and heavy boned, with a powerful muscle structure, this stone mastiff presents a formidable foe."
    ],
    arrival: [
      "A stone mastiff just came through an enormous arched doorway.",
      "A stone mastiff barrels into the area, drooling hungrily!",
      "A stone mastiff barrels in!"
    ],
    flee: [
      "A stone mastiff barrels {direction}.",
      "A stone mastiff crawls {direction}.",
      "A stone mastiff whimpers as {pronoun} slowly backs away, {pronoun} teeth bared."
    ],
    death: [
      "The stone mastiff falls to the ground and dies.",
      "The stone mastiff rolls over and dies."
    ],
    decay: [
      "A stone mastiff crumbles into a pile of rubble."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A stone mastiff shakes {pronoun} head violently as {pronoun} regains {pronoun} bearings!"
    ],
    stand: [
      "A stone mastiff growls as {pronoun} scrambles to {pronoun} feet!"
    ],
    attacks: {
      attack: [
        "A stone mastiff bares {pronoun} teeth hungrily at you!"
      ],
      claw: [
        "A stone mastiff claws at you!"
      ],
      bite: [
        "A stone mastiff tries to bite you!"
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
