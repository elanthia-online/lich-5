{
  schema_version: 3,
  name: "hobgoblin",
  noun: "",
  url: "https://gswiki.play.net/hobgoblin",
  picture: "",
  level: 3,
  family: "Goblin",
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
      name: "Cairnfang Forest",
      rooms: []
    },
    {
      name: "Snowflake Vale",
      rooms: []
    },
    {
      name: "The Graveyard",
      rooms: []
    },
    {
      name: "Wehnimer's Environs",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claidhmore",
        as: 68
      },
      {
        name: "Handaxe",
        as: 68
      },
      {
        name: "Rapier",
        as: 68
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
    asg: nil,
    immunities: [],
    melee: (4..25),
    ranged: nil,
    bolt: nil,
    udf: (54..60),
    bar_td: nil,
    cle_td: nil,
    emp_td: 9,
    pal_td: nil,
    ran_td: nil,
    sor_td: 9,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 9,
    mjs_td: nil,
    mns_td: 9,
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
    skin: "a hobgoblin scalp",
    other: nil
  },
  messaging: {
    description: [
      "This is a large humanoid creature, similar to its smaller cousin the goblin.  It has a snub nose and wide mouth with large and very sharp teeth and a greenish-yellow, leathery skin.  Reputed to be uncommonly fond of collecting treasure, these are among the most hunted beings known to exist.  But many are the whitening skulls that adorn the crude dwellings of the hobgoblin, for treasure is not all they collect."
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
