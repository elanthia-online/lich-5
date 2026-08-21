{
  schema_version: 3,
  name: "giant rat",
  noun: "",
  url: "https://gswiki.play.net/giant_rat",
  picture: "",
  level: 1,
  family: "Rodent",
  type: "Quadruped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 28,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Icemule Environs",
      rooms: []
    },
    {
      name: "Kobold Village",
      rooms: []
    },
    {
      name: "River Tunnels",
      rooms: []
    },
    {
      name: "Wehnimer's Landing",
      rooms: []
    }
  ],
  spawns: [
    { zone: 46, count: 2, uid_ranges: [[46001, 46003], [46007, 46007], [46039, 46041], [46052, 46058]] },
    { zone: 372, count: 2, uid_ranges: [[372005, 372014], [372020, 372026], [372030, 372039]] },
    { zone: 2103, count: 1, uid_ranges: [[2103007, 2103013], [2103015, 2103023]] },
    { zone: 2133, count: 2, uid_ranges: [[2133100, 2133109], [2133200, 2133206]] },
    { zone: 2134, count: 2, uid_ranges: [[2134100, 2134108], [2134200, 2134207]] },
    { zone: 2135, count: 2, uid_ranges: [[2135100, 2135107], [2135200, 2135209]] },
    { zone: 2136, count: 2, uid_ranges: [[2136100, 2136108], [2136200, 2136208]] },
    { zone: 4045, count: 3, uid_ranges: [[4045150, 4045158], [4045160, 4045168], [4045200, 4045210]] },
    { zone: 4126, count: 1, uid_ranges: [[4126004, 4126023]] }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 34
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
    asg: "1N",
    immunities: [],
    melee: 4,
    ranged: 2,
    bolt: 2,
    udf: 32,
    bar_td: 3,
    cle_td: 3,
    emp_td: nil,
    pal_td: 3,
    ran_td: nil,
    sor_td: 3,
    wiz_td: 3,
    mje_td: 3,
    mne_td: 3,
    mjs_td: 3,
    mns_td: 3,
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
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "rat pelt",
    other: nil
  },
  messaging: {
    description: [
      "Larger than a domestic cat, the giant rat stands over a foot high. Dark brown in color, shading off to white on the belly, with naked pink ears and narrow glinting eyes, the rat glares with unrestrained bloodlust. Known to exist in great packs, the rat has brought more than one over-eager adventurer to an early grave."
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
