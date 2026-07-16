{
  schema_version: 3,
  name: "monkey",
  noun: "",
  url: "https://gswiki.play.net/monkey",
  picture: "",
  level: 6,
  family: "Primate",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 60,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Citadel",
      rooms: []
    },
    {
      name: "Thurfel's Keep",
      rooms: []
    },
    {
      name: "Muddy Village",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 78
      },
      {
        name: "Mace",
        as: "(wooden cane) 70"
      },
      {
        name: "Closed fist",
        as: 88
      },
      {
        name: "Leather whip",
        as: "(red vine) 70"
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Hide"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "1",
    immunities: [],
    melee: (54..110),
    ranged: 32,
    bolt: (32..36),
    udf: (107..145),
    bar_td: 18,
    cle_td: nil,
    emp_td: 18,
    pal_td: nil,
    ran_td: nil,
    sor_td: 18,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 18,
    mjs_td: nil,
    mns_td: 18,
    mnm_td: 18,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a monkey paw",
    other: nil
  },
  messaging: {
    description: [
      ""
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
