{
  schema_version: 3,
  name: "massive black boar",
  noun: "",
  url: "https://gswiki.play.net/massive_black_boar",
  picture: "",
  level: 59,
  family: "Suine",
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
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Blighted Forest",
      rooms: []
    },
    {
      name: "Red Forest",
      rooms: []
    }
  ],
  spawns: [
    { zone: 480, count: 1, uid_ranges: [[480201, 480215]] },
    { zone: 13020, count: 2, uid_ranges: [[13020001, 13020051]] },
    { zone: 17006, count: 1, uid_ranges: [[17006201, 17006215]] }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge (attack)",
        as: 335
      },
      {
        name: "Impale (attack)",
        as: 292
      },
      {
        name: "Bite (attack)",
        as: 312
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
    asg: "12N",
    immunities: [],
    melee: (202..438),
    ranged: nil,
    bolt: nil,
    udf: 320,
    bar_td: (194..215),
    cle_td: 223,
    emp_td: (208..229),
    pal_td: nil,
    ran_td: (190..202),
    sor_td: 234,
    wiz_td: nil,
    mje_td: (253..256),
    mne_td: 246,
    mjs_td: nil,
    mns_td: 220,
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
    skin: "a heavy grey tusk",
    other: nil
  },
  messaging: {
    description: [
      "The black boar snorts loudly and scrapes at the ground, peering around with his close-set, bloodshot eyes in hopes of finding something he can gore into a bloody pulp or pound into the earth. His body is covered with coarse, black hair, and dull grey tusks protrude from each side of his gaping mouth. A good ten feet long from dripping snout to curly tail and weighing more than a ton, the black boar moves with surprising speed and dexterity as he bears down, squealing furiously, on his intended prey. The murderous glint in the boar's eyes betrays an intelligence much greater than his mundane kin."
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
