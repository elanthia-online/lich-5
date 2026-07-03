{
  schema_version: 3,
  name: "krolvin warrior",
  noun: "",
  url: "https://gswiki.play.net/krolvin_warrior",
  picture: "",
  level: 19,
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
  max_hp: 220,
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
      name: "Sea Caves",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "War mattock",
        as: 195
      },
      {
        name: "Morning star",
        as: 195
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
    asg: "12",
    immunities: [],
    melee: 186,
    ranged: (120..131),
    bolt: nil,
    udf: nil,
    bar_td: 57,
    cle_td: (54..57),
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 57,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 57,
    mjs_td: nil,
    mns_td: (54..57),
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
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "As tall as the average human, the warrior has the characteristic long-fingered hands and sturdy musculature that denote most of the krolvin race. The warrior also sports the trademark grey-blue skin and thick, coarse, white hair covers his head and spreads across his shoulders and down his back."
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
