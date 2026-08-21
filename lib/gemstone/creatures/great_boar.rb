{
  schema_version: 3,
  name: "great boar",
  noun: "",
  url: "https://gswiki.play.net/great_boar",
  picture: "",
  level: 10,
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
  max_hp: 100,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Dead Plateau",
      rooms: []
    },
    {
      name: "Old Mine Road",
      rooms: []
    },
    {
      name: "Vornavian Coast",
      rooms: []
    },
    {
      name: "Yander's Farm",
      rooms: []
    }
  ],
  spawns: [
    { zone: 92, count: 1, uid_ranges: [[92002, 92018]] },
    { zone: 395, count: 1, uid_ranges: [[395002, 395015]] },
    { zone: 4202, count: 1, uid_ranges: [[4202182, 4202199]] },
    { zone: 13000, count: 2, uid_ranges: [[13000002, 13000047]] },
    { zone: 14005, count: 1, uid_ranges: [[14005054, 14005066]] }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge",
        as: 148
      },
      {
        name: "Bite",
        as: 138
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Charge"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: 44,
    ranged: (26..29),
    bolt: nil,
    udf: nil,
    bar_td: 30,
    cle_td: nil,
    emp_td: 30,
    pal_td: nil,
    ran_td: 30,
    sor_td: 30,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 30,
    mjs_td: nil,
    mns_td: 30,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: [
      "Hides when attacked"
    ]
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
    skin: "a boar tusk",
    other: nil
  },
  messaging: {
    description: [
      "The great boar snorts loudly and scrapes at the ground, peering around with his close-set, bloodshot eyes in hopes of finding something he can gore into a bloody pulp or pound into the earth. His body is covered with coarse, mottled, grey-brown hair, and gleaming tusks protrude from each side of his gaping mouth. A good six feet long from dripping snout to curly tail and weighing more than a quarter ton, the great boar moves with surprising speed and dexterity as he bears down, squealing furiously, on his intended prey. This is one mean brute."
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
