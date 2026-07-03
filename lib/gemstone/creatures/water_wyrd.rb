{
  schema_version: 3,
  name: "water wyrd",
  noun: "",
  url: "https://gswiki.play.net/water_wyrd",
  picture: "",
  level: 35,
  family: "Elemental",
  type: "Hybrid",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Magical",
    "Element-based"
  ],
  bcs: true,
  max_hp: 260,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Ruined Tower",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Trident",
        as: (215..229)
      }
    ],
    bolt_spells: [
      {
        name: "Minor Water (903)",
        as: (212..237)
      }
    ],
    warding_spells: [
      {
        name: "Elemental Blast (409)",
        cs: (171..199)
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Major Elemental Wave (435)"
      }
    ],
    maneuvers: [
      {
        name: "Water blast"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (132..206),
    ranged: nil,
    bolt: (120..173),
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I",
      "Elemental Defense II"
    ],
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
    gems: true,
    boxes: false,
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The water wyrd's upper body is that of a humanoid, while its lower body forms a turbulent, watery vortex.  The facial features of the elemental creature are vague and shifting, rippling with every contortion of its face.  Sloshing and splashing noises accompany each movement of the water wyrd, along with an odd gurgling.</pre>"
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
