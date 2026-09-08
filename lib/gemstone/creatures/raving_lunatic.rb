{
  schema_version: 3,
  name: "raving lunatic",
  noun: "lunatic",
  url: "https://gswiki.play.net/raving_lunatic",
  picture: "",
  level: 77,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Living",
    "Extraplanar",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: 5,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "The Rift",
      uids: [4566001..4566055, 4567001..4567055]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Short sword",
        as: 371
      },
      {
        name: "Bite",
        as: (315..367)
      },
      {
        name: "Claw",
        as: (351..398)
      },
      {
        name: "Midnight black spiked whip",
        as: 415
      },
      {
        name: "Twisted kris",
        as: (391..401)
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
    asg: "8N",
    immunities: [],
    melee: (336..499),
    ranged: (276..411),
    bolt: (320..411),
    udf: (398..579),
    bar_td: 278,
    cle_td: (300..306),
    emp_td: (294..305),
    pal_td: (253..262),
    ran_td: (256..265),
    sor_td: (315..326),
    wiz_td: 330,
    mje_td: (330..337),
    mne_td: (330..337),
    mjs_td: (316..319),
    mns_td: (316..319),
    mnm_td: (242..251),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a twisted kris",
    "some tattered rags"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Tiny golden seed",
      "radiant crimson essence shard"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Perhaps driven mad by the shifting world around her, the raving lunatic babbles and chatters to herself, sometimes gleefully, sometimes angrily. A disgustingly corpulent humanoid, her rolls of pink flesh bounce and quiver as the raving lunatic staggers from area to area, not comprehending her surroundings. Clear spittle drools from her open mouth, and her unblinking eyes dart wildly about in unfocused confusion. She is a totally unpredictable foe."
    ],
    arrival: [],
    flee: [],
    death: [
      "The raving lunatic twitches violently, then dies."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A raving lunatic swings {weapon} at you!"
      ],
      bite: [
        "A raving lunatic tries to bite you!"
      ],
      claw: [
        "A raving lunatic claws at you!"
      ],
      hurl: [
        "A raving lunatic throws {weapon} at you!"
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
