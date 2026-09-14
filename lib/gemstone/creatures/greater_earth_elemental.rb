{
  schema_version: 3,
  name: "greater earth elemental",
  noun: "elemental",
  url: "https://gswiki.play.net/greater_earth_elemental",
  picture: "",
  level: 88,
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
  max_hp: 500,
  speed: 10,
  height: 12,
  size: "huge",
  areas: [
    {
      name: "Bowels of Thanatoph",
      uids: [4293015..4293057]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound (attack)"
      },
      {
        name: "Thrown Rock",
        as: 419
      },
      {
        name: "Fist",
        as: 397
      },
      {
        name: "Heavy earthen fists",
        as: 439
      },
      {
        name: "Large rock",
        as: 423
      },
      {
        name: "Foot",
        as: 440
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Ethereal Wave"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "20N",
    immunities: [],
    melee: (80..314),
    ranged: (191..276),
    bolt: (191..276),
    udf: (388..657),
    bar_td: (326..332),
    cle_td: 358,
    emp_td: (340..343),
    pal_td: (287..296),
    ran_td: (299..308),
    sor_td: 372,
    wiz_td: nil,
    mje_td: (402..405),
    mne_td: (402..405),
    mjs_td: (352..362),
    mns_td: (352..362),
    mnm_td: (264..270),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: [
      "30% damage factor reduction"
    ]
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: nil,
    other: [
      "radiant crimson essence shard",
      "essence of earth"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Massive and thick, with broad shoulders but no apparent head, the earth elemental appears to be a composite of the earth itself. A large, craggy maw in the middle of the elemental's chest appears to be the creature's mouth, and the earth elemental's huge feet and giant-sized fists look like they would pulverize flesh without much effort at all.\n\nGreater earth elementals have DFRedux which will reduce the damage factors of weapons, including bolt spells, by 30% for AS-based attacks. This is in addition to their natural full plate equivalent armor."
    ],
    arrival: [
      "A greater earth elemental lumbers in slowly.",
      "The boulder comes to a sudden stop and rises into the form of a greater krynch!",
      "A greater earth elemental lurches in, shuddering with each step."
    ],
    flee: [],
    death: [
      "The earth elemental topples to the ground motionless.",
      "The earth elemental shudders violently for a moment, then goes still."
    ],
    decay: [
      "Tiny fissures quickly spread over the entire form of a greater earth elemental.  Within moments, it crumbles into a pile of dirt and rubble.",
      "Tiny fissures quickly spread over the entire form of an earth elemental.  Within moments, it crumbles into a pile of dirt and rubble."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A greater earth elemental pounds at you with {pronoun} heavy earthen fists!",
        "A greater earth elemental pounds at you with {pronoun} fist!",
        "An earth elemental pounds at you with {pronoun} heavy earthen fists!",
        "A greater earth elemental stomps at you with {pronoun} foot!",
        "A greater earth elemental pounds at {target} with {pronoun} heavy earthen fists!"
      ],
      hurl: [
        "A greater earth elemental throws {weapon} at you!"
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
