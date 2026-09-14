{
  schema_version: 3,
  name: "lava golem",
  noun: "golem",
  url: "https://gswiki.play.net/lava_golem",
  picture: "",
  level: 56,
  family: "Golem",
  type: "Biped",
  undead: false,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: false,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Magical",
    "Element-based"
  ],
  bcs: true,
  max_hp: 500,
  speed: 11,
  height: 13,
  size: "huge",
  areas: [
    {
      name: "Eye of V'Tull",
      uids: [3060002..3060018, 3061001..3061028]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound (attack)",
        as: 325
      },
      {
        name: "Stomp (attack)",
        as: 320
      },
      {
        name: "Fist",
        as: (331..345)
      },
      {
        name: "Foot",
        as: 321
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
    asg: "12N",
    immunities: [],
    melee: (205..470),
    ranged: (105..232),
    bolt: (105..232),
    udf: (187..296),
    bar_td: nil,
    cle_td: (204..213),
    emp_td: 248,
    pal_td: (184..190),
    ran_td: (178..187),
    sor_td: (221..233),
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: (200..208),
    mns_td: (200..208),
    mnm_td: 180,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: [
      "Immune to Unbalance (110)"
    ]
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a firewheel arrow fletched with plain white feathers"
  ],
  treasure: {
    coins: nil,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: nil,
    other: "Essence of fire, Crystal core",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The lava golem is a mammoth construct of molten red hot rock and white hot eyes. Towering over twelve feet in height, it surely weighs several tons."
    ],
    arrival: [
      "A lava golem lumbers in, trailed by black wisps of smoke!",
      "A lava golem slowly lumbers in, trailed by black wisps of smoke!"
    ],
    flee: [
      "A lava golem slowly lumbers {direction}, trailed by black wisps of smoke.",
      "A lava golem lumbers {direction}, trailed by black wisps of smoke."
    ],
    death: [
      "The lava golem writhes in fiery agony and dies.",
      "The lava golem topples to the ground as the fire slowly leaves it.",
      "A lava golem topples heavily to the ground!",
      "The lava golem falls to the floor dead, {pronoun} husk still pulsating with a blinding white hue."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    stun_break: [
      "The lava golem shrugs off the blow, then the living lava that the lava golem is made of reforms {pronoun} missing right arm!",
      "The lava golem shrugs off the blow, then the living lava that the lava golem is made of reforms {pronoun} missing left arm!",
      "The lava golem shrugs off the blow, then the living lava that the lava golem is made of reforms {pronoun} missing right hand!",
      "The lava golem shrugs off the blow, then the living lava that the lava golem is made of reforms {pronoun} missing left hand!"
    ],
    attacks: {
      attack: [
        "A lava golem pounds at you with {pronoun} fist!",
        "A lava golem stomps at you with {pronoun} foot!"
      ],
      hurl: [
        "A lava golem hurls a glob of lava at you!"
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
