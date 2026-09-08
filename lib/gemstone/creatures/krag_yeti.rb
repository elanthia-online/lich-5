{
  schema_version: 3,
  name: "krag yeti",
  noun: "yeti",
  url: "https://gswiki.play.net/krag_yeti",
  picture: "",
  level: 70,
  family: "Yeti",
  type: "Biped",
  undead: false,
  blood: true,
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
  max_hp: 400,
  speed: nil,
  height: 10,
  size: "large",
  areas: [
    {
      name: "Krag Slopes",
      uids: [495101..495116]
    },
    {
      name: "The Hidden Plateau",
      uids: [2167001..2167022]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Hairy hand",
        as: (328..364)
      },
      {
        name: "Ensnare",
        as: 335
      },
      {
        name: "Closed fist",
        as: (346..388)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Arm Entrapment/Bear Hug"
      },
      {
        name: "Ground slap"
      },
      {
        name: "Hairy hand"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (265..526),
    ranged: (258..350),
    bolt: (258..350),
    udf: 357,
    bar_td: (210..262),
    cle_td: (270..276),
    emp_td: (272..278),
    pal_td: (227..230),
    ran_td: 230,
    sor_td: (280..289),
    wiz_td: nil,
    mje_td: (293..302),
    mne_td: (293..302),
    mjs_td: (266..274),
    mns_td: (266..274),
    mnm_td: (204..213),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye",
    "a bruised right eye",
    "a possible mild concussion"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Tiny golden seed",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A towering mound of fur that belies her swift blinding speed, the krag yeti is at home either in the sub-zero wasteland or on rocky mountain tops. The krag yeti's white fur allows an almost perfect blend with the natural surroundings, enabling the creature to move with uncommon stealth. Legendary strength and fury make her a formidable opponent for any who would cross her."
    ],
    arrival: [
      "A krag yeti stomps in, a fetid odor wafting before it.",
      "The boulder comes to a sudden stop and rises into the form of a krag dweller!"
    ],
    flee: [
      "A krag yeti rumbles {direction}.",
      "A krag yeti hobbles slowly {direction}, groaning in pain."
    ],
    death: [
      "The krag yeti shudders once before it finally goes still.",
      "The krag yeti collapses to the ground and shudders once before finally going still."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A krag yeti swings {weapon} at you!",
        "A krag yeti tries to ensnare you!"
      ],
      hurl: [
        "A krag yeti throws a large rock at you!"
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
