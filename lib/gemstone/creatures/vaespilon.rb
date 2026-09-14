{
  schema_version: 3,
  name: "vaespilon",
  noun: "vaespilon",
  url: "https://gswiki.play.net/vaespilon",
  picture: "",
  level: 93,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead",
    "Extraplanar"
  ],
  bcs: true,
  max_hp: 300,
  speed: 8,
  height: 6,
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
        name: "Implosion (720)"
      },
      {
        name: "Spirit Strike (117)"
      },
      {
        name: "Bravery (211)"
      },
      {
        name: "Blackened wooden staff",
        as: 495
      }
    ],
    maneuvers: [
      {
        name: "Skeletal Finger"
      },
      {
        name: "Pounce"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "2",
    immunities: [],
    melee: (283..521),
    ranged: (201..423),
    bolt: (201..423),
    udf: (381..617),
    bar_td: nil,
    cle_td: (399..409),
    emp_td: (385..391),
    pal_td: (359..362),
    ran_td: (347..356),
    sor_td: (416..425),
    wiz_td: nil,
    mje_td: (434..439),
    mne_td: (434..439),
    mjs_td: 419,
    mns_td: 419,
    mnm_td: (365..369),
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)",
      "Lesser Shroud (120)",
      "Wall of Force (140)",
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
    "a blackened wooden staff",
    "a scorched black pendant",
    "a twisted black ring",
    "some decaying black robes",
    "some rotting black robes"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Inky necrotic core",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The vaespilon's features are so terribly deformed by death's ravages, her expression is one of almost comical surprise, until her smile widens into a grin that is a study in terror. The skin covering the walking corpse is mottled and stretched unevenly over the bones, and the surface ripples and bulges as if putrescence is bubbling underneath. The vaespilon hisses in glee as she moves, a wave of stench preceding her like an invisible assailant."
    ],
    arrival: [
      "A vaespilon crawls in, wailing in pain!"
    ],
    flee: [],
    death: [
      "The vaespilon falls to the ground motionless.",
      "The vaespilon wails in terrifying pain one last time and lies still."
    ],
    decay: [
      "All the malice and magic that once held the vaespilon together dissipates, leaving nothing but a husk which crumbles to dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A vaespilon swings {weapon} at you!"
      ],
      cast: [
        "A vaespilon points a skeletal finger at {target}!"
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
