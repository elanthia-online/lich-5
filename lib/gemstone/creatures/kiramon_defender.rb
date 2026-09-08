{
  schema_version: 3,
  name: "kiramon defender",
  noun: "defender",
  url: "https://gswiki.play.net/kiramon_defender",
  picture: "",
  level: 46,
  family: "Kiramon",
  type: "Insect",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: 7,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Darkstone Castle",
      uids: [41019..41025, 41027..41029, 41034..41050]
    },
    {
      name: "unmapped",
      uids: [41026..41026]
    },
    {
      name: "Abandoned Mine",
      uids: [3005003..3005012, 3005014..3005022]
    },
    {
      name: "Czeroth Caverns",
      uids: [13007201..13007228]
    },
    {
      name: "Maernstrike Caverns",
      uids: [13037001..13037020]
    },
    {
      name: "The Hive",
      uids: [13041001..13041026]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Tongue Strike",
        as: 256
      },
      {
        name: "Charge (attack)",
        as: 262
      },
      {
        name: "Claw",
        as: (230..256)
      },
      {
        name: "Charge",
        as: 236
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Disease",
        cs: "Poison"
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Hamstring"
      }
    ],
    special_abilities: [
      {
        name: "Lunge"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (192..402),
    ranged: (198..260),
    bolt: (195..260),
    udf: (275..431),
    bar_td: (160..163),
    cle_td: (178..187),
    emp_td: (168..177),
    pal_td: (152..161),
    ran_td: (152..158),
    sor_td: (177..195),
    wiz_td: nil,
    mje_td: nil,
    mne_td: (198..201),
    mjs_td: (168..183),
    mns_td: (168..183),
    mnm_td: (138..147),
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
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: "a kiramon tongue",
    other: [
      "glowing mineral water",
      "tiny golden seed"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The kiramon defender has a mobile head with huge, bulging, eyes that sparkle in a faceted clustering around a lidless perimeter. Protruding from his massive head is a vicious-looking snout with insectile mandibles, while the back of his cranium is a distended, two-lobed case. Remarkably powerful rear legs jut backward from an extremely hard, resilient exoskeleton that seems to be in constant motion. Though his middle legs have evolved away long ago, his front legs end in strong opposing claws and knobby-jointed fingers. Stunted wings flap uselessly from his long cylindrical body."
    ],
    arrival: [],
    flee: [
      "A kiramon defender heads {direction}.",
      "A kiramon defender limps {direction}."
    ],
    death: [
      "The kiramon defender falls back into a heap and dies.",
      "The kiramon defender clicks one last time and dies."
    ],
    decay: [
      "A kiramon defender crumbles away into dust."
    ],
    search: [],
    spell_prep: [
      "A kiramon defender hisses sharply! {pronoun} long, piercing tongue comes shooting out at you..."
    ],
    attacks: {
      attack: [
        "A kiramon defender charges at you!"
      ],
      bite: [
        "A kiramon defender snaps {pronoun} pincers noisily."
      ],
      claw: [
        "A kiramon defender claws at you!"
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
