{
  schema_version: 3,
  name: "stone giant",
  noun: "",
  url: "https://gswiki.play.net/stone_giant",
  picture: "",
  level: 58,
  family: "Giant",
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
  max_hp: 600,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Thanatoph",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound",
        as: (324..346)
      },
      {
        name: "Stomp",
        as: (324..346)
      },
      {
        name: "War mattock",
        as: (324..346)
      }
    ],
    bolt_spells: [
      {
        name: "Hurl Boulder (510)",
        as: 334
      }
    ],
    warding_spells: [
      {
        name: "Unbalance (110)",
        cs: (251..263)
      }
    ],
    offensive_spells: [
      {
        name: "Earthen Fury (917)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "20N",
    immunities: [],
    melee: (167..317),
    ranged: nil,
    bolt: nil,
    udf: (261..474),
    bar_td: 202,
    cle_td: 219,
    emp_td: nil,
    pal_td: 192,
    ran_td: nil,
    sor_td: 241,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: 216,
    mnm_td: 186,
    defensive_spells: [
      "Natural Colors",
      "Resist Elements",
      "Self Control"
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
    other: nil
  },
  messaging: {
    description: [
      "Looming high above you, taller than three of the tallest giantmen, this stone giant dominates the surrounding area.  The stone giant's skin is a smooth dull grey with mottled brown splotches and its eyes, concealed under a heavy brow, gleam black with hatred."
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
