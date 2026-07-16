{
  schema_version: 3,
  name: "ghostly mara",
  noun: "",
  url: "https://gswiki.play.net/ghostly_mara",
  picture: "",
  level: 32,
  family: "Ghost",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Wraithenmist",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Longsword",
        as: "(blackened) 238"
      },
      {
        name: "Falchion",
        as: "(dull) 238"
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Lullabye"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "7",
    immunities: [],
    melee: 266,
    ranged: nil,
    bolt: (160..172),
    udf: nil,
    bar_td: 111,
    cle_td: (113..122),
    emp_td: nil,
    pal_td: 96,
    ran_td: nil,
    sor_td: 124,
    wiz_td: 125,
    mje_td: 125,
    mne_td: 127,
    mjs_td: nil,
    mns_td: 117,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense III"
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
      "The image of a wandering minstrel greets the scrutinizing eye. The ghostly mara takes many forms, often times wearing the rotting and wornout gear of foreign lands. Her voice, so essential to her lifestyle in the former life, has taken on the unearthly sounds of a spirit long dead."
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
