{
  schema_version: 3,
  name: "huge earth elemental",
  noun: "",
  url: "https://gswiki.play.net/huge_earth_elemental",
  picture: "",
  level: 95,
  family: "Elemental",
  type: "Elemental",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Extraplanar",
    "Magical"
  ],
  bcs: true,
  max_hp: nil,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Elemental Confluence",
      rooms: []
    }
  ],
  spawns: [
    { zone: 580, count: 1, uid_ranges: [[580001, 580025]] },
    { zone: 581, count: 1, uid_ranges: [[581001, 581025]] },
    { zone: 582, count: 1, uid_ranges: [[582001, 582025]] },
    { zone: 583, count: 1, uid_ranges: [[583001, 583025]] },
    { zone: 584, count: 1, uid_ranges: [[584001, 584025]] },
    { zone: 585, count: 1, uid_ranges: [[585001, 585025]] },
    { zone: 586, count: 1, uid_ranges: [[586001, 586025]] },
    { zone: 587, count: 1, uid_ranges: [[587001, 587025]] },
    { zone: 588, count: 1, uid_ranges: [[588001, 588025]] },
    { zone: 4070, count: 1, uid_ranges: [[4070501, 4070519]] }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound",
        as: 460
      }
    ],
    bolt_spells: [
      {
        name: "Hurl Boulder (510)",
        as: 463
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Ground slap"
      }
    ],
    special_abilities: [
      {
        name: "Stone touch"
      },
      {
        name: "Earthquake"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "20",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: 284,
    udf: nil,
    bar_td: 401,
    cle_td: 410,
    emp_td: 410,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 410,
    mns_td: 410,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Barrier",
      "Elemental Bias",
      "Elemental Defense I",
      "Elemental Defense II",
      "Elemental Defense III",
      "Elemental Targeting"
    ],
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
    skin: nil,
    other: "essence of earth"
  },
  messaging: {
    description: [
      "Massive and thick, with broad shoulders but no apparent head, the earth elemental appears to be a composite of the earth itself. A large, craggy maw in the middle of the elemental's chest appears to be the creature's mouth, and the earth elemental's huge feet and giant-sized fists look like they would pulverize flesh without much effort at all."
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
