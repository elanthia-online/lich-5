{
  schema_version: 3,
  name: "luminous worm",
  noun: "worm",
  url: "https://gswiki.play.net/luminous_worm",
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
  max_hp: 146,
  speed: 9,
  height: 1,
  size: "medium",
  areas: [
    {
      name: "Hornwort Cavern",
      uids: [7131001..7131018]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge (attack)",
        as: 156
      },
      {
        name: "Charge",
        as: (154..162)
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
    asg: nil,
    immunities: [],
    melee: (62..98),
    ranged: (46..82),
    bolt: (46..82),
    udf: (73..122),
    bar_td: nil,
    cle_td: (45..54),
    emp_td: (42..48),
    pal_td: (45..54),
    ran_td: (48..54),
    sor_td: (48..51),
    wiz_td: nil,
    mje_td: 51,
    mne_td: 51,
    mjs_td: (48..63),
    mns_td: (48..63),
    mnm_td: (42..51),
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
    other: [
      "ayanad crystal",
      "s'ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [],
    arrival: [
      "A luminous worm slithers into view, its glow illuminating the area."
    ],
    flee: [
      "A luminous worm backs away, a foul odor spewing out from {pronoun} as {pronoun} inches backwards."
    ],
    death: [
      "A luminous worm slumps to the ground, its glowing form now motionless and dull."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A worm charges at you!",
        "A luminous worm charges at you!"
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
