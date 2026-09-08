{
  schema_version: 3,
  name: "night hound",
  noun: "hound",
  url: "https://gswiki.play.net/night_hound",
  picture: "",
  level: 24,
  family: "Canine",
  type: "Quadruped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
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
  max_hp: 210,
  speed: 7,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "The Graveyard",
      uids: [2150002..2150007, 2150010..2150014]
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
        as: (182..202)
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
    melee: (124..149),
    ranged: (106..141),
    bolt: (106..143),
    udf: (111..143),
    bar_td: 97,
    cle_td: 99,
    emp_td: 101,
    pal_td: nil,
    ran_td: 97,
    sor_td: 104,
    wiz_td: nil,
    mje_td: (101..107),
    mne_td: (101..107),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: 97,
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
    "a bruised right eye",
    "a completely severed right paw"
  ],
  treasure: {
    coins: true,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a night hound hide",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [],
    arrival: [],
    flee: [
      "A night hound pads {direction}, a mist of shadows puffing from {pronoun} nostrils."
    ],
    death: [
      "The night hound lets out one last whimpering sigh of dark and shadowy whirlwinds and dies."
    ],
    decay: [
      "A night hound decays into a compost of fur and fangs."
    ],
    search: [
      "The night hound sniffs at the air and growls low in the throat."
    ],
    spell_prep: [],
    stun_break: [
      "A night hound howls in rage as {pronoun} shakes off the stun.",
      "A night hound howls silently in rage as {pronoun} shakes off the stun."
    ],
    attacks: {
      attack: [
        "A night hound belches a dark cloud at you!"
      ],
      claw: [
        "A night hound claws at you!"
      ],
      bite: [
        "A night hound tries to bite you!"
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
