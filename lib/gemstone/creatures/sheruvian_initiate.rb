{
  schema_version: 3,
  name: "Sheruvian initiate",
  noun: "initiate",
  url: "https://gswiki.play.net/sheruvian_initiate",
  picture: "",
  level: 37,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 238,
  speed: 6,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "The Broken Lands",
      uids: [487010..487014, 487016..487016, 487018..487025, 487027..487031, 487034..487041, 487043..487052, 487054..487054, 487056..487058, 487067..487075]
    },
    {
      name: "unmapped",
      uids: [487015..487015, 487017..487017, 487042..487042, 487053..487053, 487055..487055, 487076..487076]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Jeddart-axe",
        as: (230..280)
      },
      {
        name: "Lunge",
        as: 220
      },
      {
        name: "Closed fist",
        as: 220
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Healing"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (212..319),
    ranged: (196..284),
    bolt: (188..284),
    udf: 259,
    bar_td: 127,
    cle_td: 139,
    emp_td: 140,
    pal_td: (116..119),
    ran_td: 119,
    sor_td: 146,
    wiz_td: nil,
    mje_td: 153,
    mne_td: 153,
    mjs_td: (155..190),
    mns_td: (155..190),
    mnm_td: 111,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a black steel jeddart-axe",
    "some black velvet robes"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The Sheruvian initiate is much as a monk of the same order, a foul spawn of inhuman parents with a head shaved smooth and covered in dark, mystic runes though fewer and less elaborate. What they appear to lack in intelligence, they make up for in belligerence."
    ],
    arrival: [
      "A Sheruvian initiate just came through a sculpted black vaalin arch.",
      "A Sheruvian initiate just came through a polished engraved maoral door.",
      "A Sheruvian initiate just came through a small wooden door.",
      "A Sheruvian initiate just came through a sturdy iron-bound door.",
      "A Sheruvian initiate just came through a curtained polished ivory arch."
    ],
    flee: [],
    death: [
      "A Sheruvian initiate lunges at you, exclaiming, \"I've seen children put up a better fight than this fool!  Now he dies!\"",
      "The Sheruvian initiate screams emotionlessly one last time and lies still.",
      "The Sheruvian initiate falls to the ground and lies still."
    ],
    decay: [],
    search: [
      "The Sheruvian initiate searches around looking for something.",
      "The Sheruvian initiate glances around, sure {pronoun} has missed something."
    ],
    spell_prep: [],
    attacks: {
      attack: [
        "A Sheruvian initiate lunges at you, exclaiming, \"I've seen children put up a better fight than this fool!  Now he dies!\"",
        "A Sheruvian initiate swings {weapon} at you!",
        "A Sheruvian initiate leaps to {pronoun} feet, {pronoun} eyes darting around looking for trouble."
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
