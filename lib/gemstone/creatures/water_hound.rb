{
  schema_version: 3,
  name: "water hound",
  noun: "hound",
  url: "https://gswiki.play.net/water_hound",
  picture: "",
  level: 24,
  family: "Canine",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
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
        as: (182..192)
      },
      {
        name: "Claw",
        as: 202
      },
      {
        name: "Stream of water",
        as: 202
      }
    ],
    bolt_spells: [
      {
        name: "Minor Water (903)",
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
    melee: (133..141),
    ranged: (86..206),
    bolt: (86..206),
    udf: (141..145),
    bar_td: nil,
    cle_td: 74,
    emp_td: 76,
    pal_td: (69..72),
    ran_td: 72,
    sor_td: 79,
    wiz_td: nil,
    mje_td: (81..82),
    mne_td: (81..82),
    mjs_td: 76,
    mns_td: 76,
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
  equipment: [
    "a case of sporadic convulsions"
  ],
  treasure: {
    coins: true,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "water hound pelt",
    other: "Essence of water",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [],
    arrival: [
      "A water hound arrives, shaking droplets of water from {pronoun} {weapon}, blue fur ruff!",
      "A water hound arrives, shaking droplets of water from {pronoun} slick, blue fur ruff!"
    ],
    flee: [
      "A water hound pads {direction}, a dense mist puffing from {pronoun} nostrils."
    ],
    death: [
      "The water hound lets out one last whimpering sigh of water droplets and dies."
    ],
    decay: [
      "A water hound decays into a compost of fur and fangs."
    ],
    search: [
      "The water hound sniffs at the air and growls low in the throat."
    ],
    spell_prep: [],
    stun_break: [
      "A water hound howls in rage as {pronoun} shakes off the stun.",
      "A water hound howls silently in rage as {pronoun} shakes off the stun."
    ],
    attacks: {
      attack: [
        "A water hound belches a bolt of water at you!"
      ],
      bite: [
        "A water hound tries to bite you!"
      ],
      claw: [
        "A water hound claws at you!"
      ],
      hurl: [
        "A water hound hurls {weapon} at you!"
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
