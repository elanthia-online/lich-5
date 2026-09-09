{
  schema_version: 3,
  name: "white vysan",
  noun: "vysan",
  url: "https://gswiki.play.net/white_vysan",
  picture: "",
  level: 3,
  family: "Vysan",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
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
  max_hp: 50,
  speed: 12,
  height: 4,
  size: "small",
  areas: [
    {
      name: "Southern Snowfields",
      uids: [4128058..4128070]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ensnare",
        as: 54
      },
      {
        name: "Pound",
        as: 44
      },
      {
        name: "Fist",
        as: (34..44)
      },
      {
        name: "Unknown",
        as: 44
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
    asg: "1N",
    immunities: [],
    melee: 18,
    ranged: 13,
    bolt: 13,
    udf: 51,
    bar_td: nil,
    cle_td: 9,
    emp_td: 9,
    pal_td: (6..9),
    ran_td: 9,
    sor_td: 9,
    wiz_td: nil,
    mje_td: 9,
    mne_td: 9,
    mjs_td: (9..15),
    mns_td: (9..15),
    mnm_td: 9,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
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
      "The white vysan is a peculiar beast, ivory white and extremely bloated with gas to the point that it can float from place to place. Its appendages extend straight out from its rotund body, and its head resembles an overturned kettle. Blending in well with snowy backgrounds, it prefers cold, icy areas, moving slowly from location to location in search of food."
    ],
    arrival: [],
    flee: [],
    death: [
      "The white vysan falls to the ground motionless.",
      "The white vysan screams evilly one last time and goes still."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A white vysan pounds at you with {pronoun} fist!",
        "A white vysan tries to ensnare you!"
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
