{
  schema_version: 3,
  name: "gnoll ranger",
  noun: "ranger",
  url: "https://gswiki.play.net/gnoll_ranger",
  picture: "",
  level: 15,
  family: "Gnoll",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 134,
  speed: 10,
  height: 3,
  size: "small",
  areas: [
    {
      name: "Foothills of Zeltoph",
      uids: [10001..10020, 10200..10206]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Handaxe",
        as: 171
      },
      {
        name: "Unknown",
        as: 150
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Sounds (607)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8",
    immunities: [],
    melee: (156..198),
    ranged: (15..108),
    bolt: 135,
    udf: 172,
    bar_td: nil,
    cle_td: (42..48),
    emp_td: (38..48),
    pal_td: (42..52),
    ran_td: (42..45),
    sor_td: 45,
    wiz_td: nil,
    mje_td: (44..55),
    mne_td: (44..55),
    mjs_td: (39..48),
    mns_td: (39..48),
    mnm_td: (39..45),
    defensive_spells: [
      "Natural Colors (601)",
      "Resist Elements (602)",
      "Spirit Warding I (101)",
      "Spirit Defense (103)"
    ],
    defensive_abilities: [],
    special_defenses: [
      "Hides when attacked"
    ]
  },
  special_other: "Foraging",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a handaxe",
    "a wooden shield",
    "some brown"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: [
      "green double leather"
    ],
    transmogs: nil
  },
  messaging: {
    description: [
      "This gnoll is dressed for the out-of-doors. His rough clothing that blends into the landscape marks him as a ranger. Used to the ways of weapons and hunting, the gnoll's small stature should not be cause to regard him lightly."
    ],
    arrival: [
      "A gnoll ranger stalks in.",
      "A gnoll ranger wanders in, alertly surveying its surroundings."
    ],
    flee: [
      "A gnoll ranger stalks {direction}."
    ],
    death: [
      "The gnoll ranger falls to the ground and dies.",
      "The gnoll ranger rolls over and dies."
    ],
    decay: [
      "A gnoll ranger's remains dissolve into the ground."
    ],
    search: [],
    spell_prep: [
      "A gnoll ranger whispers a string of delicate words.",
      "A gnoll ranger gestures towards you!"
    ],
    attacks: {
      hurl: [
        "A gnoll ranger throws a handaxe at you!"
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
