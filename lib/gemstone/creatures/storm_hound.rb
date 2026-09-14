{
  schema_version: 3,
  name: "storm hound",
  noun: "hound",
  url: "https://gswiki.play.net/storm_hound",
  picture: "",
  level: 24,
  family: "Canine",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 210,
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
      },
      {
        name: "Powerful lightning bolt",
        as: 202
      }
    ],
    bolt_spells: [
      {
        name: "Major Shock (910)",
        as: 171
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: 206,
    ranged: (106..206),
    bolt: (106..206),
    udf: 143,
    bar_td: nil,
    cle_td: 74,
    emp_td: 76,
    pal_td: (69..72),
    ran_td: 72,
    sor_td: 79,
    wiz_td: nil,
    mje_td: (81..82),
    mne_td: (81..82),
    mjs_td: (76..101),
    mns_td: (76..101),
    mnm_td: 72,
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
  equipment: [],
  treasure: {
    coins: true,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "storm hound paw",
    other: "Essence of air",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [],
    arrival: [],
    flee: [
      "A storm hound pads {direction}, a static-charged blue mist puffing from {pronoun} nostrils."
    ],
    death: [
      "The storm hound lets out one last whimpering sigh of sparks and blue mist and dies."
    ],
    decay: [
      "A storm hound decays into a compost of fur and fangs."
    ],
    search: [
      "The storm hound sniffs at the air and growls low in the throat."
    ],
    spell_prep: [],
    stun_break: [
      "A storm hound howls in rage as {pronoun} shakes off the stun.",
      "A storm hound howls silently in rage as {pronoun} shakes off the stun."
    ],
    attacks: {
      attack: [
        "A storm hound barks thunder and lightning at you!"
      ],
      hurl: [
        "A storm hound hurls {weapon} at you!"
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
