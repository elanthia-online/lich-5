{
  schema_version: 3,
  name: "thrak",
  noun: "thrak",
  url: "https://gswiki.play.net/thrak",
  picture: "",
  level: 8,
  family: "Reptilian",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: nil,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 85,
  speed: 7,
  height: 1,
  size: "medium",
  areas: [
    {
      name: "Old Mine Road",
      uids: [20019..20028, 20030..20038]
    },
    {
      name: "Vornavian Coast",
      uids: [4202182..4202199]
    },
    {
      name: "Liath Bheinn and Aillidh Brae",
      uids: [4250004..4250021]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 110
      },
      {
        name: "Charge",
        as: 120
      },
      {
        name: "Claw",
        as: 110
      },
      {
        name: "Unknown",
        as: 120
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
    asg: "11N",
    immunities: [],
    melee: (47..68),
    ranged: (48..57),
    bolt: (48..57),
    udf: (77..79),
    bar_td: 24,
    cle_td: 24,
    emp_td: 24,
    pal_td: 24,
    ran_td: 24,
    sor_td: 24,
    wiz_td: 24,
    mje_td: 24,
    mne_td: 24,
    mjs_td: (24..27),
    mns_td: (24..27),
    mnm_td: 24,
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
    skin: "a thrak hide",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "This odd creature looks unnatural, as though some wizard had been meddling with its shape. It looks like a large, 4-foot-long lizard, with an uncomfortably large variety of teeth in its long snout."
    ],
    arrival: [
      "A thrak scampers in."
    ],
    flee: [
      "The thrak scampers {direction}."
    ],
    death: [
      "The thrak falls back into a heap and dies.",
      "The thrak hisses one last time and dies."
    ],
    decay: [
      "A thrak decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A thrak charges at you!"
      ],
      bite: [
        "A thrak tries to bite you!"
      ],
      claw: [
        "A thrak claws at you!"
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
