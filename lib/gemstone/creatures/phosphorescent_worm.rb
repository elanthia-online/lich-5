{
  schema_version: 3,
  name: "phosphorescent worm",
  noun: "worm",
  url: "https://gswiki.play.net/phosphorescent_worm",
  picture: "",
  level: 16,
  family: "Worm",
  type: "Worm",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 150,
  speed: 7,
  height: 1,
  size: "medium",
  areas: [
    {
      name: "Thurfel's Island",
      uids: [7532001..7532033]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge (attack)",
        as: 154
      },
      {
        name: "Charge",
        as: 154
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Pounce"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (56..90),
    ranged: (52..82),
    bolt: (52..82),
    udf: (73..122),
    bar_td: (45..51),
    cle_td: (45..54),
    emp_td: (45..54),
    pal_td: (45..54),
    ran_td: (45..54),
    sor_td: (42..54),
    wiz_td: nil,
    mje_td: 48,
    mne_td: 48,
    mjs_td: (45..54),
    mns_td: (45..54),
    mnm_td: (42..48),
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
    skin: "a faintly glowing worm skin",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The beast before you bears similarities to an earthworm, except it is considerably larger. The beast has a gaping maw filled with tiny sharp teeth. The phosphorescent slime coating the worm serves to both protect the beast and perhaps distract its foes."
    ],
    arrival: [
      "A phosphorescent worm slithers into view, its glow illuminating the area."
    ],
    flee: [
      "A phosphorescent worm backs away, a foul odor spewing out from {pronoun} as {pronoun} inches backwards."
    ],
    death: [
      "A phosphorescent worm slumps to the ground, its glowing form now motionless and dull."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A phosphorescent worm charges at you!"
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
