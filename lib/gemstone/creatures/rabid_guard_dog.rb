{
  schema_version: 3,
  name: "rabid guard dog",
  noun: "dog",
  url: "https://gswiki.play.net/rabid_guard_dog",
  picture: "",
  level: 10,
  family: "Canine",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 100,
  speed: 6,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Thurfel's Island",
      uids: [7531001..7531010]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 106
      },
      {
        name: "Charge (attack)"
      },
      {
        name: "Charge",
        as: 106
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Leap"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [],
    melee: (65..87),
    ranged: (25..44),
    bolt: (25..44),
    udf: (93..97),
    bar_td: 30,
    cle_td: 30,
    emp_td: (30..33),
    pal_td: (27..30),
    ran_td: 30,
    sor_td: 30,
    wiz_td: nil,
    mje_td: 30,
    mne_td: 30,
    mjs_td: (27..33),
    mns_td: (27..33),
    mnm_td: 30,
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
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a rotted canine",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Smaller than most dogs, the short hair of this beast is mangy and unkempt. Its beady eyes gaze alertly in all directions, while his stubby tail flicks back and forth with rhythmic precision."
    ],
    arrival: [],
    flee: [
      "A rabid guard dog rushes {direction}!",
      "A rabid guard dog whimpers as {pronoun} slowly backs away, {pronoun} teeth bared."
    ],
    death: [
      "The guard dog falls to the ground and dies.",
      "The guard dog rolls over and dies."
    ],
    decay: [
      "A rabid guard dog decays into a compost of fangs and fur."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A rabid guard dog shakes {pronoun} head violently while trying to regain {pronoun} bearings!"
    ],
    attacks: {
      attack: [
        "A rabid guard dog charges at you!"
      ],
      bite: [
        "A rabid guard dog tries to bite you!"
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
