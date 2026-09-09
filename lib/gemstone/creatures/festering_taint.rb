{
  schema_version: 3,
  name: "festering taint",
  noun: "taint",
  url: "https://gswiki.play.net/festering_taint",
  picture: "",
  level: 86,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 238,
  speed: 4,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Old Ta'Faendryl",
      uids: [17003011..17003038, 17003101..17003150, 17003201..17003217]
    },
    {
      name: "unmapped",
      uids: [17003001..17003010]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (370..408)
      }
    ],
    bolt_spells: [
      {
        name: "Fire Spirit (111)",
        as: 369
      }
    ],
    warding_spells: [
      {
        name: "Curse (715)",
        cs: 379
      },
      {
        name: "Dark Catalyst (719)",
        cs: 379
      },
      {
        name: "Disease (716)",
        cs: 379
      },
      {
        name: "Disintegrate (705)",
        cs: 379
      },
      {
        name: "Mind Jolt (706)",
        cs: 379
      },
      {
        name: "Unbalance (110)",
        cs: 366
      },
      {
        name: "Claw",
        cs: 367
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Grasp of the Grave (709)"
      }
    ],
    maneuvers: [
      {
        name: "Putrid Air"
      },
      {
        name: "Point"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (327..472),
    ranged: (291..371),
    bolt: (310..371),
    udf: (396..549),
    bar_td: 327,
    cle_td: 367,
    emp_td: (339..352),
    pal_td: (305..315),
    ran_td: (290..296),
    sor_td: (340..380),
    wiz_td: nil,
    mje_td: (378..384),
    mne_td: (378..384),
    mjs_td: (339..349),
    mns_td: (339..349),
    mnm_td: (303..310),
    defensive_spells: [
      "Lesser Shroud (120)",
      "Spirit Defense (103)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)",
      "Wall of Force (140)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a possible mild concussion"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "tiny golden seed",
      "ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The festering taint is a putrescent collection of rotting flesh and disease. The gender of the taint is impossible to make out due to the scabs and boils which cover its skin, oozing out disgustingly. Black and yellow rotting teeth are displayed in a mouth that is unnaturally wide underneath two black eyes that stare out with a frightening spark of intelligence. No nose or ears are visible on the festering taint, but it has a mop of greasy, filthy black hair that sprouts from the top of its head."
    ],
    arrival: [
      "A festering taint arrives, bringing in a rancid odor.",
      "A festering taint arrives with a disgusting stench.",
      "A festering taint arrives with a grin that displays blackened and rotting teeth."
    ],
    flee: [],
    death: [
      "The festering taint sinks to its knees as it chokes on its own blood and dies.",
      "The festering taint crumples to the ground, spits out a curse, and dies.",
      "The festering taint falls to the ground, cursing, and dies.",
      "The festering taint spasms uncontrollably as it goes into shock and dies.",
      "The festering taint lets out a final curse as it dies.",
      "The festering taint screams with rage as it falls to the ground and dies.",
      "The festering taint curses the day it was created and dies."
    ],
    decay: [
      "A festering taint's corpse falls apart and dissolves with a sudden hiss.",
      "A festering taint's body dissolves, bubbling and fizzing until nothing is left."
    ],
    search: [],
    spell_prep: [
      "A festering taint mutters a phrase of magic."
    ],
    stun_break: [
      "A festering taint gibbers, spittle flying from {pronoun} mouth as {pronoun} tries to regain {pronoun} senses."
    ],
    attacks: {
      attack: [
        "A festering taint points a putrid hand at you!",
        "A festering taint exhales the last of a virulent green mist."
      ],
      claw: [
        "A festering taint claws at you!"
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
