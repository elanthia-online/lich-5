{
  schema_version: 3,
  name: "forest trali",
  noun: "trali",
  url: "https://gswiki.play.net/forest_trali",
  picture: "",
  level: 44,
  family: "Trali",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Gyldemar Forest",
      uids: [13028038..13028080]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Broadsword",
        as: (244..274)
      },
      {
        name: "Dart",
        as: 298
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
    asg: "9",
    immunities: [],
    melee: (185..337),
    ranged: (187..286),
    bolt: (187..286),
    udf: (238..403),
    bar_td: (132..141),
    cle_td: (142..151),
    emp_td: (144..153),
    pal_td: (126..132),
    ran_td: (123..132),
    sor_td: (153..159),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 168,
    mjs_td: 170,
    mns_td: 170,
    mnm_td: (123..132),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a battered breastplate",
    "a battered shield",
    "a stain-darkened broadsword"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a trali hide",
    other: [
      "Glowing violet essence shard",
      "tiny golden seed"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Standing nearly six feet tall, the man-like forest trali watches adventurers' every move with piercing grey eyes. A short matted, reddish grey mane covers her head and her skin has a greenish grey hue. There is little doubt that the stealthy forest trali can be a formidable opponent when need arises, or when she is hard pressed."
    ],
    arrival: [
      "A forest trali arrives, sniffing the air for prey!",
      "A forest trali stalks in."
    ],
    flee: [
      "A forest trali tramps {direction}.",
      "A forest trali limps {direction}.",
      "A forest trali just went through a battered maoral door."
    ],
    death: [
      "The forest trali twitches violently, then dies.",
      "A forest trali collapses upon the ground and the life fades from {pronoun} eyes.",
      "A forest trali collapses upon the floor and the life fades from {pronoun} eyes."
    ],
    decay: [
      "A forest trali's body rapidly decays away."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A forest trali swings {weapon} at you!",
        "A forest trali shoots a tiny dart at you!",
        "A forest trali leaps to {pronoun} feet!"
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
