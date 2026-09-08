{
  schema_version: 3,
  name: "skeleton",
  noun: "skeleton",
  url: "https://gswiki.play.net/skeleton",
  picture: "",
  level: 1,
  family: "Humanoid",
  type: "Biped",
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
  max_hp: 40,
  speed: 15,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Glaise Cnoc Cemetery",
      uids: [14008001..14008033, 14008060..14008070]
    },
    {
      name: "The Graveyard",
      uids: [18003..18009, 2162201..2162211]
    },
    {
      name: "Southern Snowfields",
      uids: [4128063..4128067]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Broadsword"
      },
      {
        name: "Dagger",
        as: 31
      },
      {
        name: "Unknown",
        as: 31
      },
      {
        name: "Bite",
        as: 11
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "5",
    immunities: [],
    melee: (0..21),
    ranged: (-13..19),
    bolt: (-13..19),
    udf: 34,
    bar_td: 3,
    cle_td: 3,
    emp_td: 3,
    pal_td: (0..3),
    ran_td: 3,
    sor_td: 3,
    wiz_td: 3,
    mje_td: 3,
    mne_td: 3,
    mjs_td: 3,
    mns_td: 3,
    mnm_td: 3,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a dagger",
    "a woven cloak",
    "some light leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "skeleton bone",
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The skeleton clatters noisily about as if lost in the world of the living. Bleached bones, barely connected by stiff, crystallized tendons, tell a story of flesh long rotted away. Cockroaches, maggots and other insect types, perhaps still feeding on the rotting remains of the brain of the skeleton, scuttle and slither liberally in and out of the cranial sockets."
    ],
    arrival: [
      "A skeleton just arrived!",
      "A skeleton just arrived."
    ],
    flee: [],
    death: [
      "The skeleton falls to the ground motionless.",
      "The skeleton screams evilly one last time and goes still."
    ],
    decay: [
      "A skeleton turns to dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A skeleton swings {weapon} at you!"
      ],
      bite: [
        "A skeleton tries to bite you!"
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
