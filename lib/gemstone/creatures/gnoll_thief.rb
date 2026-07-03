{
  schema_version: 3,
  name: "gnoll thief",
  noun: "",
  url: "https://gswiki.play.net/gnoll_thief",
  picture: "",
  level: 13,
  family: "Gnoll",
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
  max_hp: 160,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Zeltoph",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Short sword",
        as: 162
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "[[Thrown weapons|Hurl]]"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "6",
    immunities: [],
    melee: 176,
    ranged: nil,
    bolt: (72..109),
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 45,
    wiz_td: nil,
    mje_td: (33..45),
    mne_td: (33..45),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: [
      "Hides when attacked"
    ]
  },
  special_other: "Stealing",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Yes"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Light fingered and agile, the gnoll thief is easily at home in both the dark stone corridors of his lair and anywhere that loot may be gained.  Wiry and lithe, with pale skin and large, colorless eyes, the thief stands around three feet tall as it regards you uneasily.</pre>"
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
