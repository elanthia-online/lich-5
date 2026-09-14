{
  schema_version: 3,
  name: "sand devil",
  noun: "devil",
  url: "https://gswiki.play.net/sand_devil",
  picture: "",
  level: 48,
  family: "Reptilian",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 240,
  speed: 5,
  height: 2,
  size: "medium",
  areas: [
    {
      name: "Fhorian Village",
      uids: [3030201..3030210]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw (attack)",
        as: 273
      },
      {
        name: "Pound (attack)",
        as: 303
      },
      {
        name: "Claw",
        as: 293
      },
      {
        name: "Fist",
        as: 303
      },
      {
        name: "Small surge of electricity",
        as: 283
      },
      {
        name: "Stream of water",
        as: 283
      }
    ],
    bolt_spells: [
      {
        name: "Minor Shock (901)",
        as: 283
      },
      {
        name: "Minor Water (903)",
        as: 273
      },
      {
        name: "Minor Fire (906)",
        as: 263
      },
      {
        name: "Minor Cold (1709)",
        as: 263
      }
    ],
    warding_spells: [
      {
        name: "Web (118)"
      }
    ],
    offensive_spells: [
      {
        name: "Sandstorm (914)"
      },
      {
        name: "Energy Maelstrom (710)"
      },
      {
        name: "Tangleweed (610)"
      }
    ],
    maneuvers: [
      {
        name: "Lash"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "2N",
    immunities: [],
    melee: (249..477),
    ranged: (317..416),
    bolt: (317..416),
    udf: (505..560),
    bar_td: (168..171),
    cle_td: 184,
    emp_td: (183..185),
    pal_td: (187..190),
    ran_td: (157..159),
    sor_td: (196..197),
    wiz_td: nil,
    mje_td: (203..206),
    mne_td: (203..206),
    mjs_td: (183..185),
    mns_td: (183..185),
    mnm_td: 172,
    defensive_spells: [
      "Spirit Warding II (107)",
      "Lesser Shroud (120)",
      "Wall of Force (140)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Elemental Targeting (425)",
      "Elemental Barrier (430)",
      "Mobility (618)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a crystal wand",
    "a giant clamshell shield",
    "a metal wand",
    "a slender blue wand",
    "some dirty turquoise robes",
    "some dusty green robes",
    "some ripped blue robes",
    "some tattered ochre robes"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "glowing violet essence dust",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Mutiple attack abilities, including a command of many offensive spells, make the sand devil a most dangerous adversary. Its name comes from the appearance of its leathery, yellowish, reptilian head crowned with two long, upright, black horns. The sand devil swirls in and out of areas, constantly rotating to keep the wind and dust whipping around it. This allows its sharp claws to remain hidden, emerging suddenly from the sandstorm to slash at surprised foes."
    ],
    arrival: [
      "A sand devil charges in."
    ],
    flee: [],
    death: [
      "The sand devil screams one last time and dies.",
      "The sand devil falls to the ground and dies."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A sand devil mutters some guttural sounds.",
      "A sand devil gestures at {target}!"
    ],
    attacks: {
      attack: [
        "A sand devil pounds at you with {pronoun} fist!",
        "A sand devil shoots strands of webbing at you!",
        "A sand devil waves {pronoun} silver wand at you."
      ],
      claw: [
        "A sand devil claws at {target}!"
      ],
      hurl: [
        "A sand devil hurls {weapon} at you!"
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
