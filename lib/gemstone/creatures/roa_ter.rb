{
  schema_version: 3,
  name: "roa'ter",
  noun: "",
  url: "https://gswiki.play.net/roa'ter",
  picture: "",
  level: 41,
  family: "Worm",
  type: "Worm",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 260,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Castle Varunar",
      rooms: []
    },
    {
      name: "Darkstone Castle",
      rooms: []
    },
    {
      name: "Czeroth Labyrinth",
      rooms: []
    }
  ],
  spawns: [
    { zone: 42, count: 1, uid_ranges: [[42500, 42521]] },
    { zone: 4218, count: 1, uid_ranges: [[4218101, 4218121]] },
    { zone: 4750, count: 2, uid_ranges: [[4750006, 4750029]] },
    { zone: 13007, count: 1, uid_ranges: [[13007201, 13007228]] },
    { zone: 13041, count: 1, uid_ranges: [[13041001, 13041026]] }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge",
        as: 244
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Burrow"
      },
      {
        name: "Tail Slam"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (142..332),
    ranged: (134..169),
    bolt: (134..169),
    udf: 323,
    bar_td: nil,
    cle_td: 142,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 154,
    wiz_td: nil,
    mje_td: 165,
    mne_td: nil,
    mjs_td: 146,
    mns_td: 146,
    mnm_td: nil,
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
    boxes: true,
    skin: "roa'ter skin",
    other: nil
  },
  messaging: {
    description: [
      "This massive worm is probably over twenty to thirty feet long, making it an easy target to hit, but having incomparable force and strength. Dark red in color, it seems to have no eyes, but its keen sense of smell quickly finds targets."
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
