{
  schema_version: 3,
  name: "ghostly mara",
  noun: "mara",
  url: "https://gswiki.play.net/ghostly_mara",
  picture: "",
  level: 32,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 238,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Wraithenmist",
      uids: [13027023..13027086]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Longsword",
        as: 208
      },
      {
        name: "Falchion",
        as: 208
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
    melee: (139..271),
    ranged: (138..200),
    bolt: (138..200),
    udf: (177..319),
    bar_td: 111,
    cle_td: (113..122),
    emp_td: (114..123),
    pal_td: (95..105),
    ran_td: (89..99),
    sor_td: (121..127),
    wiz_td: 125,
    mje_td: (127..131),
    mne_td: (127..131),
    mjs_td: (104..117),
    mns_td: (104..117),
    mnm_td: (99..109),
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
  equipment: [
    "a banded steel shield",
    "a blackened longsword",
    "a dulled falchion",
    "a ragged great kilt",
    "a reinforced shield",
    "a rotting targe",
    "a serrated falchion",
    "some rotting leather hunts",
    "some tattered leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Glimmering blue essence shard",
      "glimmering blue mote of essence"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The image of a wandering minstrel greets the scrutinizing eye. The ghostly mara takes many forms, often times wearing the rotting and wornout gear of foreign lands. Her voice, so essential to her lifestyle in the former life, has taken on the unearthly sounds of a spirit long dead."
    ],
    arrival: [],
    flee: [
      "A ghostly mara floats {direction}."
    ],
    death: [
      "A haunting melody fills the air and fades as a ghostly mara dissipates into nothing."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A ghostly mara musically intones an arcane song."
    ],
    attacks: {
      attack: [
        "A mara swings {weapon} at you!",
        "A ghostly mara swings {weapon} at you!",
        "A ghostly mara directs the sound of {pronoun} voice at you!"
      ]
    },
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
