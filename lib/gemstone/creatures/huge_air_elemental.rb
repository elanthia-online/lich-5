{
  schema_version: 3,
  name: "huge air elemental",
  noun: "elemental",
  url: "https://gswiki.play.net/huge_air_elemental",
  picture: "",
  level: 95,
  family: "Elemental",
  type: "Elemental",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: nil,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Extraplanar",
    "Magical"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Elemental Confluence",
      uids: [580001..580025, 581001..581025, 582001..582025, 583001..583025, 584001..584025, 585001..585025, 586001..586025, 587001..587025, 588001..588025]
    }
  ],
  attack_attributes: {
    physical_attacks: [],
    bolt_spells: [
      {
        name: "Hand of Tonis (505)",
        as: 448
      }
    ],
    warding_spells: [
      {
        name: "Slow (504)",
        cs: 335
      }
    ],
    offensive_spells: [
      {
        name: "Call Wind (912)"
      },
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Major Elemental Wave (435)"
      },
      {
        name: "Wind blast"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "10",
    immunities: [],
    melee: nil,
    ranged: (320..328),
    bolt: 312,
    udf: nil,
    bar_td: nil,
    cle_td: 410,
    emp_td: 410,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 410,
    mns_td: 410,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Barrier",
      "Elemental Bias",
      "Elemental Defense I",
      "Elemental Defense II",
      "Elemental Defense III",
      "Elemental Targeting"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: nil,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: nil,
    other: "essence of air",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The air elemental is a vaguely humanoid whirlwind of unusually dense air. Its constant spin is almost hypnotic, though it radiates a palpable disdain for all solid life."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [
      "A huge air elemental whispers an incantation into the wind."
    ],
    attacks: {
      attack: [
        "A huge air elemental unleashes a bolt of churning air at you!",
        "A huge air elemental takes a deep breath, opens {pronoun} mouth and blows a forceful gust of air at you!",
        "A huge air elemental spins rapidly at you!"
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
