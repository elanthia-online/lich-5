{
  schema_version: 3,
  name: "crocodile",
  noun: "crocodile",
  url: "https://gswiki.play.net/crocodile",
  picture: "",
  level: 9,
  family: "Reptilian",
  type: "Quadruped",
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
  max_hp: 92,
  speed: 14,
  height: 1,
  size: "medium",
  areas: [
    {
      name: "The Citadel",
      uids: [377051..377066, 377077..377081, 377083..377084]
    },
    {
      name: "unmapped",
      uids: [377067..377076, 377082..377082]
    },
    {
      name: "Plains of Vornavis",
      uids: [4212301..4212324]
    },
    {
      name: "Thurfel's Island",
      uids: [7530006..7530029]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge (attack)",
        as: 137
      },
      {
        name: "Bite",
        as: 127
      },
      {
        name: "Charge",
        as: (70..137)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Disease (on hit)"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "16N",
    immunities: [],
    melee: (45..81),
    ranged: (31..50),
    bolt: (31..50),
    udf: (74..96),
    bar_td: 33,
    cle_td: (18..27),
    emp_td: (18..27),
    pal_td: (18..27),
    ran_td: (18..27),
    sor_td: (18..27),
    wiz_td: nil,
    mje_td: (18..27),
    mne_td: (18..27),
    mjs_td: (27..48),
    mns_td: (27..48),
    mnm_td: (18..27),
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
    skin: "a crocodile snout",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A large scaled lizard, with a wide gaping mouth full of sharp teeth, it has short powerful legs barely long enough to lift the beast off the ground. The crocodile also has a long powerful tail that looks rather dangerous."
    ],
    arrival: [
      "A florid mauve crocodile slithers in.",
      "A striped blue crocodile slithers in.",
      "A brilliant red crocodile slithers in.",
      "A speckled tangerine crocodile slithers in.",
      "A crocodile slithers in."
    ],
    flee: [
      "The crocodile slithers {direction}."
    ],
    death: [
      "The crocodile falls back into a heap and dies.",
      "The crocodile hisses one last time and dies.",
      "The blue crocodile falls back into a heap and dies.",
      "The mauve crocodile falls back into a heap and dies.",
      "The blue crocodile hisses one last time and dies.",
      "The mauve crocodile hisses one last time and dies.",
      "The red crocodile falls back into a heap and dies.",
      "The tangerine crocodile hisses one last time and dies.",
      "The red crocodile hisses one last time and dies.",
      "The tangerine crocodile falls back into a heap and dies."
    ],
    decay: [
      "A crocodile decays into compost.",
      "A striped blue crocodile decays into compost.",
      "A florid mauve crocodile decays into compost.",
      "A brilliant red crocodile decays into compost.",
      "A speckled tangerine crocodile decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A crocodile charges at you!"
      ],
      bite: [
        "A crocodile tries to bite you!"
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
