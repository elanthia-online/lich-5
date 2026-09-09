{
  schema_version: 3,
  name: "vapor hound",
  noun: "hound",
  url: "https://gswiki.play.net/vapor_hound",
  picture: "",
  level: 24,
  family: "Canine",
  type: "Quadruped",
  undead: true,
  blood: false,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 211,
  speed: 7,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Stormpeak",
      uids: [13150101..13150120]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 192
      },
      {
        name: "Claw",
        as: 202
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Breath attack"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (126..141),
    ranged: (107..131),
    bolt: (107..131),
    udf: (141..145),
    bar_td: nil,
    cle_td: 99,
    emp_td: 101,
    pal_td: (94..97),
    ran_td: 97,
    sor_td: 104,
    wiz_td: nil,
    mje_td: (106..107),
    mne_td: (106..107),
    mjs_td: 101,
    mns_td: 101,
    mnm_td: 97,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: [
      "Shakes off stuns"
    ]
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye",
    "a bruised right eye",
    "a completely severed right foreleg"
  ],
  treasure: {
    coins: true,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "vapor hound tail",
    other: [
      "Essence of air",
      "elemental core"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [],
    arrival: [],
    flee: [
      "A vapor hound pads {direction}, a fog of green vapor puffing from {pronoun} nostrils."
    ],
    death: [
      "The vapor hound lets out one last whimpering sigh of chartreuse vapors and dies."
    ],
    decay: [
      "A vapor hound decays into a compost of fur and fangs."
    ],
    search: [
      "The vapor hound sniffs at the air and growls low in the throat."
    ],
    spell_prep: [],
    stun_break: [
      "A vapor hound howls in rage as {pronoun} shakes off the stun.",
      "A vapor hound howls silently in rage as {pronoun} shakes off the stun."
    ],
    attacks: {
      attack: [
        "A vapor hound opens {pronoun} mouth with a yawning sigh, letting out a blast of green vapors at you!"
      ],
      bite: [
        "A vapor hound tries to bite you!"
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
