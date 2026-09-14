{
  schema_version: 3,
  name: "huge earth elemental",
  noun: "elemental",
  url: "https://gswiki.play.net/huge_earth_elemental",
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
  max_hp: 298,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Elemental Confluence",
      uids: [580001..580025, 581001..581025, 582001..582025, 583001..583025, 584001..584025, 585001..585025, 586001..586025, 587001..587025, 588001..588025]
    },
    {
      name: "unmapped",
      uids: [4070501..4070519]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound",
        as: 460
      }
    ],
    bolt_spells: [
      {
        name: "Hurl Boulder (510)",
        as: 463
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Ground slap"
      }
    ],
    special_abilities: [
      {
        name: "Stone touch"
      },
      {
        name: "Earthquake"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "20",
    immunities: [],
    melee: nil,
    ranged: (197..289),
    bolt: (197..289),
    udf: nil,
    bar_td: 401,
    cle_td: 410,
    emp_td: 410,
    pal_td: nil,
    ran_td: 357,
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
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: nil,
    other: "essence of earth",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Massive and thick, with broad shoulders but no apparent head, the earth elemental appears to be a composite of the earth itself. A large, craggy maw in the middle of the elemental's chest appears to be the creature's mouth, and the earth elemental's huge feet and giant-sized fists look like they would pulverize flesh without much effort at all."
    ],
    arrival: [
      "A huge earth elemental lurches in, shuddering with each step."
    ],
    flee: [],
    death: [],
    decay: [
      "Tiny fissures quickly spread over the entire form of a huge earth elemental.  Within moments, it crumbles into a pile of dirt and rubble."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A huge earth elemental pounds at you with a heavy earthen fist!"
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
