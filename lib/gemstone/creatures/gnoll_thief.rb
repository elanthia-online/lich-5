{
  schema_version: 3,
  name: "gnoll thief",
  noun: "thief",
  url: "https://gswiki.play.net/gnoll_thief",
  picture: "",
  level: 13,
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
  max_hp: 160,
  speed: 7,
  height: 3,
  size: "small",
  areas: [
    {
      name: "Foothills of Zeltoph",
      uids: [10001..10020, 10201..10206]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Short sword",
        as: 162
      },
      {
        name: "Unknown",
        as: 159
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Hurl"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "6",
    immunities: [],
    melee: 176,
    ranged: (67..100),
    bolt: (67..109),
    udf: (197..202),
    bar_td: nil,
    cle_td: (39..45),
    emp_td: (31..39),
    pal_td: (36..45),
    ran_td: nil,
    sor_td: 45,
    wiz_td: nil,
    mje_td: (33..45),
    mne_td: (33..45),
    mjs_td: (33..39),
    mns_td: (33..39),
    mnm_td: (36..45),
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
  equipment: [
    "a dark cloth pouch",
    "a grey leather bag",
    "a grey oilcloth bag",
    "a short sword",
    "a sooty cloth sack",
    "a sooty cotton pouch",
    "a sooty oilcloth bag",
    "a sooty oilcloth sack",
    "a stained brocade pouch",
    "a stained brocade sack",
    "a stained cloth pouch",
    "a stained cotton pouch",
    "a stained cotton sack",
    "a stained leather sack",
    "an ink black leather bag",
    "an ink black oilcloth sack",
    "some dark full leather"
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
      "Light fingered and agile, the gnoll thief is easily at home in both the dark stone corridors of his lair and anywhere that loot may be gained. Wiry and lithe, with pale skin and large, colorless eyes, the thief stands around three feet tall as it regards you uneasily."
    ],
    arrival: [],
    flee: [
      "A gnoll thief skulks {direction}."
    ],
    death: [
      "The gnoll thief rolls over and dies.",
      "The gnoll thief falls to the ground and dies."
    ],
    decay: [
      "A gnoll thief's remains dissolve into the ground."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      hurl: [
        "A gnoll thief throws a short sword at you!"
      ],
      attack: [
        "A gnoll thief swings an archaic steel handaxe at you!"
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
