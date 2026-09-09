{
  schema_version: 3,
  name: "water moccasin",
  noun: "moccasin",
  url: "https://gswiki.play.net/water_moccasin",
  picture: "",
  level: 4,
  family: "Reptilian",
  type: "Ophidian",
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
  speed: 8,
  height: 1,
  size: "small",
  areas: [
    {
      name: "The Graveyard",
      uids: [2156016..2156025]
    },
    {
      name: "The Toadwort",
      uids: [14007012..14007041]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 68
      },
      {
        name: "Unknown",
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
    asg: "5N",
    immunities: [],
    melee: (28..37),
    ranged: (28..33),
    bolt: (28..33),
    udf: 21,
    bar_td: 12,
    cle_td: 12,
    emp_td: 12,
    pal_td: (9..12),
    ran_td: 12,
    sor_td: 12,
    wiz_td: nil,
    mje_td: 12,
    mne_td: 12,
    mjs_td: 39,
    mns_td: 39,
    mnm_td: 12,
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
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a water moccasin's ",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The water moccasin appears to be at least three feet long, with dark olive-colored skin. You also note a faint diamond pattern travelling down from head to tail. When the mouth opens you can see a sickly white lining within."
    ],
    arrival: [
      "A water moccasin slithers in!"
    ],
    flee: [
      "A water moccasin slithers {direction}."
    ],
    death: [],
    decay: [
      "A water moccasin decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      bite: [
        "A water moccasin tries to bite you!"
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
