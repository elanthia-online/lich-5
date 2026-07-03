{
  schema_version: 3,
  name: "wind witch",
  noun: "",
  url: "https://gswiki.play.net/wind_witch",
  picture: "",
  level: 16,
  family: "Witch",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living",
    "Element-based"
  ],
  bcs: true,
  max_hp: 140,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Foggy Valley",
      rooms: []
    },
    {
      name: "Wehntoph",
      rooms: []
    },
    {
      name: "Stormpeak",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Dagger",
        as: 161
      },
      {
        name: "Knife",
        as: 161
      }
    ],
    bolt_spells: [
      {
        name: "Minor Shock (901)",
        as: 139
      },
      {
        name: "Major Shock (910)",
        as: 139
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Call Wind (912)"
      }
    ],
    maneuvers: [],
    special_abilities: [
      {
        name: "[[Gas cloud]]"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "2",
    immunities: [],
    melee: 131,
    ranged: nil,
    bolt: (106..116),
    udf: nil,
    bar_td: (54..59),
    cle_td: nil,
    emp_td: nil,
    pal_td: 53,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: (44..59),
    mne_td: (44..59),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I",
      "Elemental Defense II",
      "Thurfel's Ward (503)"
    ],
    defensive_abilities: [],
    special_defenses: [
      "Shake off [[Stun|stuns]]"
    ]
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
    skin: "a crooked witch nose",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Standing in the center of a swirling whorl of wind, the wind witch cackles evilly.  Dull grey eyes stare out at you from under an unruly mop of tangled grey hair.  The wind witch's bluish skin stands out against the tattered robes it wears.</pre>"
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
