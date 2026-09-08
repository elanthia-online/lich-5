{
  schema_version: 3,
  name: "earth elemental",
  noun: "elemental",
  url: "https://gswiki.play.net/earth_elemental",
  picture: "",
  level: 82,
  family: "Elemental",
  type: "Elemental",
  undead: false,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: false,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Extraplanar",
    "Magical"
  ],
  bcs: true,
  max_hp: 400,
  speed: 10,
  height: 10,
  size: "huge",
  areas: [
    {
      name: "Bowels of Thanatoph",
      uids: [4293001..4293032, 4293051..4293057]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound (attack)",
        as: 401
      },
      {
        name: "Foot",
        as: 422
      },
      {
        name: "Heavy earthen fists",
        as: 421
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
    asg: "20N",
    immunities: [],
    melee: (102..293),
    ranged: (146..274),
    bolt: (146..274),
    udf: (421..662),
    bar_td: nil,
    cle_td: 333,
    emp_td: (312..315),
    pal_td: (277..286),
    ran_td: (268..274),
    sor_td: (366..375),
    wiz_td: nil,
    mje_td: 369,
    mne_td: 369,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: (246..252),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: [
      "30% weapon damage factor reduction"
    ]
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a massive iron-banded greatshield",
    "a massive pitted iron pavis"
  ],
  treasure: {
    coins: true,
    magic_items: false,
    gems: true,
    boxes: false,
    skin: nil,
    other: "essence of earth",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Massive and thick, with broad shoulders but no apparent head, the earth elemental appears to be a composite of the earth itself. A large, craggy maw in the middle of the elemental's chest appears to be the creature's mouth, and the earth elemental's huge feet and giant-sized fists look like they would pulverize flesh without much effort at all."
    ],
    arrival: [
      "An earth elemental lumbers in slowly."
    ],
    flee: [
      "An earth elemental lumbers slowly to the {direction}."
    ],
    death: [
      "The earth elemental topples to the ground motionless.",
      "The earth elemental shudders violently for a moment, then goes still.",
      "The earth elemental falls to the floor dead, {pronoun} still pulsating with a blinding white hue."
    ],
    decay: [
      "Tiny fissures quickly spread over the entire form of an earth elemental.  Within moments, it crumbles into a pile of dirt and rubble.",
      "Tiny fissures quickly spread over the entire form of a greater earth elemental.  Within moments, it crumbles into a pile of dirt and rubble."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "An earth elemental pounds at you with {pronoun} heavy earthen fists!",
        "An earth elemental stomps at you with {pronoun} foot!"
      ],
      hurl: [
        "An earth elemental throws a large rock at you!"
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
