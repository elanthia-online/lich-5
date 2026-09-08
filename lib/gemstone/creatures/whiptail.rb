{
  schema_version: 3,
  name: "whiptail",
  noun: "whiptail",
  url: "https://gswiki.play.net/whiptail",
  picture: "",
  level: 4,
  family: "Arachnid",
  type: "Arachnid",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
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
  max_hp: 50,
  speed: 6,
  height: 1,
  size: "medium",
  areas: [
    {
      name: "Vornavian Coast",
      uids: [4202401..4202416]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Impale",
        as: 65
      },
      {
        name: "Pincer (attack)",
        as: 65
      },
      {
        name: "Pincer",
        as: 65
      },
      {
        name: "Tusk",
        as: (45..65)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Web"
      }
    ],
    special_abilities: [
      {
        name: "Web"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (32..59),
    ranged: (29..36),
    bolt: (29..36),
    udf: (54..60),
    bar_td: 12,
    cle_td: 12,
    emp_td: (6..12),
    pal_td: (9..12),
    ran_td: 12,
    sor_td: 12,
    wiz_td: nil,
    mje_td: 12,
    mne_td: 12,
    mjs_td: 12,
    mns_td: 12,
    mnm_td: 12,
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
    skin: "a whiptail stinger",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "This creature resembles nothing so much as a giant scorpion, easily capable of hunting prey as large as a man. Longer than a halfling is tall, its giant insectile body scuttles about on 8 swift legs, armed with two pincer claws over a foot long. It gazes at its prey with cold-gleaming faceted eyes, while its segmented tail, tipped with a deadly sting, arches over its body, ready to reach out with poisonous agony."
    ],
    arrival: [],
    flee: [
      "A whiptail scurries {direction}."
    ],
    death: [
      "The whiptail falls back and dies.",
      "The whiptail hisses one last time and dies."
    ],
    decay: [
      "A whiptail decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A whiptail charges at you with {pronoun} tusk!",
        "A whiptail snaps at you with {pronoun} pincer!",
        "A whiptail spins a web at you!"
      ],
      bite: [
        "A whiptail snaps at you with {pronoun} pincer!"
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
