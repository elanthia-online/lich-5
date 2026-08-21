{
  schema_version: 3,
  name: "kiramon defender",
  noun: "",
  url: "https://gswiki.play.net/kiramon_defender",
  picture: "",
  level: 46,
  family: "Kiramon",
  type: "Insect",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: "6",
  height: nil,
  size: "",
  areas: [
    {
      name: "Darkstone Castle",
      rooms: []
    },
    {
      name: "Kharam Dzu",
      rooms: []
    },
    {
      name: "Seethe Naedal",
      rooms: []
    },
    {
      name: "Czeroth Labyrinth",
      rooms: []
    }
  ],
  spawns: [
    { zone: 41, count: 2, uid_ranges: [[41019, 41029], [41034, 41050]] },
    { zone: 3005, count: 2, uid_ranges: [[3005003, 3005012], [3005014, 3005022]] },
    { zone: 13007, count: 2, uid_ranges: [[13007201, 13007228]] },
    { zone: 13037, count: 1, uid_ranges: [[13037001, 13037020]] },
    { zone: 13041, count: 1, uid_ranges: [[13041001, 13041026]] }
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
        as: 256
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
    melee: 188,
    ranged: 205,
    bolt: 195,
    udf: 234,
    bar_td: (160..163),
    cle_td: 178,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: (177..195),
    wiz_td: nil,
    mje_td: nil,
    mne_td: (198..201),
    mjs_td: 177,
    mns_td: (168..183),
    mnm_td: 177,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: nil,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: "a kiramon tongue",
    other: "glowing mineral water"
  },
  messaging: {
    description: [
      "The kiramon defender has a mobile head with huge, bulging, eyes that sparkle in a faceted clustering around a lidless perimeter. Protruding from his massive head is a vicious-looking snout with insectile mandibles, while the back of his cranium is a distended, two-lobed case. Remarkably powerful rear legs jut backward from an extremely hard, resilient exoskeleton that seems to be in constant motion. Though his middle legs have evolved away long ago, his front legs end in strong opposing claws and knobby-jointed fingers. Stunted wings flap uselessly from his long cylindrical body."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
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
