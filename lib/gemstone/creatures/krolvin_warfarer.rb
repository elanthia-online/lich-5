{
  schema_version: 3,
  name: "krolvin warfarer",
  noun: "",
  url: "https://gswiki.play.net/krolvin_warfarer",
  picture: "",
  level: 25,
  family: "Krolvin",
  type: "Biped",
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
  max_hp: 280,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Abandoned Mine",
      rooms: []
    },
    {
      name: "Krolvin Ship",
      rooms: []
    },
    {
      name: "Old Mine Road",
      rooms: []
    },
    {
      name: "Sea Caves",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Awl-pike",
        as: 200
      },
      {
        name: "Claidhmore",
        as: 200
      },
      {
        name: "Falchion",
        as: 200
      },
      {
        name: "Morning star",
        as: 196
      }
    ],
    bolt_spells: [
      {
        name: "Fire Spirit (111)",
        as: 179
      }
    ],
    warding_spells: [
      {
        name: "Elemental Blast (409)",
        cs: 127
      },
      {
        name: "Unbalance (110)",
        cs: 130
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Wave (410)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: nil,
    ranged: (117..212),
    bolt: nil,
    udf: nil,
    bar_td: (63..89),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 85,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: 87,
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Spirit Defense (103)",
      "Spirit Fog (106)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)"
    ],
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
    skin: nil,
    other: "Glimmering blue essence shard"
  },
  messaging: {
    description: [
      "As tall as the average human, the warfarer has the characteristic long-fingered hands and sturdy musculature that denote most of the krolvin race. The warfarer also sports the trademark grey-blue skin and thick, coarse, white hair covers his head and spreads across his shoulders and down his back."
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
