{
  schema_version: 3,
  name: "lost soul",
  noun: "soul",
  url: "https://gswiki.play.net/lost_soul",
  picture: "",
  level: 91,
  family: "Ghost",
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
    "Non-corporeal undead",
    "Extraplanar"
  ],
  bcs: true,
  max_hp: 238,
  speed: 8,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "The Rift",
      uids: [4570001..4570014]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Scythe",
        as: (370..493)
      },
      {
        name: "Scorched black ball and chain",
        as: (404..501)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Elemental Dispel (417)"
      },
      {
        name: "Gleaming silvery scythe",
        cs: 383
      },
      {
        name: "Scorched black ball and chain",
        cs: 380
      }
    ],
    maneuvers: [
      {
        name: "Point"
      },
      {
        name: "Pounce"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (270..520),
    ranged: (236..409),
    bolt: (236..409),
    udf: (360..630),
    bar_td: nil,
    cle_td: 407,
    emp_td: (419..428),
    pal_td: 370,
    ran_td: (329..332),
    sor_td: (379..442),
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 430,
    mns_td: 430,
    mnm_td: (321..327),
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Elemental Barrier (430)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a gleaming silvery scythe",
    "a scorched black ball",
    "a shimmering black shield"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "inky necrotic core",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The lost soul appears as the flickering shade of a normal humanoid, his face contorted into a soundless, agonized scream. His flesh slowly melts off his frame, bubbling, dripping to the ground, and his clothing turns into rags, dropping off in shreds, until nothing is left but a skeleton with hate-filled red eyes. Slowly the flesh reforms, the clothing regains its form, all in nearly reverse order, until the lost soul is once again whole. Then, horribly, he begins to deteriorate again."
    ],
    arrival: [],
    flee: [
      "A lost soul floats {direction}."
    ],
    death: [
      "A lost soul fades into oblivion."
    ],
    decay: [
      "A lost soul fades into oblivion."
    ],
    search: [],
    spell_prep: [
      "A lost soul gestures and utters a phrase of arcane magic.",
      "A lost soul's eyes glow an eerie pale green!"
    ],
    attacks: {
      attack: [
        "A lost soul points both spectral hands at you!",
        "A lost soul swings {weapon} at you!"
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
