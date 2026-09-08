{
  schema_version: 3,
  name: "fire mage",
  noun: "mage",
  url: "https://gswiki.play.net/fire_mage",
  picture: "",
  level: 71,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Living",
    "Element-based",
    "Boss"
  ],
  bcs: true,
  max_hp: 238,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Eye of V'Tull",
      uids: [3051005..3051020, 3051022..3051030, 3061001..3061017, 3061028..3061038]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 115
      },
      {
        name: "Gnarled black staff",
        as: 274
      }
    ],
    bolt_spells: [
      {
        name: "Major Fire (908)",
        as: 311
      }
    ],
    warding_spells: [
      {
        name: "Earthen Fury"
      },
      {
        name: "Firestorm"
      },
      {
        name: "Sleep"
      },
      {
        name: "Tremors"
      },
      {
        name: "Weapon Fire"
      },
      {
        name: "Feras mattock",
        cs: 324
      }
    ],
    maneuvers: [
      {
        name: "Fire Bolt"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [],
    melee: (233..400),
    ranged: (256..380),
    bolt: (256..380),
    udf: (302..482),
    bar_td: (251..285),
    cle_td: (296..306),
    emp_td: (292..302),
    pal_td: (253..263),
    ran_td: (251..260),
    sor_td: (316..328),
    wiz_td: nil,
    mje_td: (333..345),
    mne_td: (333..345),
    mjs_td: (292..311),
    mns_td: (292..311),
    mnm_td: (233..243),
    defensive_spells: [
      "Elemental Barrier",
      "Elemental Defense I",
      "Elemental Defense II",
      "Elemental Defense III",
      "Elemental Focus",
      "Elemental Targeting",
      "Mass Blur",
      "Prismatic Guard",
      "Thurfel's Ward"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a gnarled black staff",
    "some sooty black robes"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "essence of fire",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The fire mage isn't tall, standing no more than five feet, but her harrowing image is more than intimidating. Blackened skin of her face is framed with a wild mane of silvery hair, which lifts in the smoke and flames rising from the mage's robes like writhing serpents. Twin pits of fire glare out of the apparition's eye sockets, constantly sweeping her surroundings with maleficent intent."
    ],
    arrival: [
      "Violent flames begin to whip and spit about the area as a fire mage strides into view!",
      "A fire mage strides in!",
      "An apt fire mage strides in!"
    ],
    flee: [
      "A fire mage crawls {direction}.",
      "A fire mage walks {direction}.",
      "A fire mage strides south, leaving traces of fire in the air.",
      "A fire mage strides north, leaving traces of fire in the air."
    ],
    death: [
      "The fire mage goes limp and {pronoun} falls over as the fire slowly fades from {pronoun} eyes.",
      "The fire mage twitches violently, then dies.",
      "The fire in the fire mage's eyes slowly fades away."
    ],
    decay: [
      "A fire mage decays into a fine grey ash that quickly blows away.",
      "An apt fire mage decays into a fine grey ash that quickly blows away."
    ],
    search: [
      "A fire mage looks around apprehensively as {pronoun} takes a step back."
    ],
    spell_prep: [
      "A fire mage gestures mystically, leaving a trail of fire in the air!"
    ],
    attacks: {
      attack: [
        "A fire mage leaves a trail of fire in the air while gesturing at you!",
        "A fire mage swings {weapon} at you!"
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
