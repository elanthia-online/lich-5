{
  schema_version: 3,
  name: "shelfae chieftain",
  noun: "chieftain",
  url: "https://gswiki.play.net/shelfae_chieftain",
  picture: "",
  level: 11,
  family: "Shelfae",
  type: "Hybrid",
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
  max_hp: 140,
  speed: 7,
  height: 7,
  size: "medium",
  areas: [
    {
      name: "Coastal Cliffs",
      uids: [84408..84413, 84416..84419]
    },
    {
      name: "Plains of Vornavis",
      uids: [4212301..4212324]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Halberd",
        as: 130
      },
      {
        name: "Morning star",
        as: 130
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Tail strike"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "11",
    immunities: [],
    melee: (6..42),
    ranged: (3..7),
    bolt: (3..7),
    udf: (80..90),
    bar_td: 33,
    cle_td: 33,
    emp_td: (27..33),
    pal_td: (30..33),
    ran_td: 33,
    sor_td: 33,
    wiz_td: nil,
    mje_td: 33,
    mne_td: 33,
    mjs_td: (33..54),
    mns_td: (33..54),
    mnm_td: 33,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a halberd"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a shelfae crest",
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Similar to the shelfae soldier but taller by nearly two feet, the shelfae chieftain guides the legions of shelfae in combat. Its taller stature, significantly brighter orange coloration, and protruding crest mark it as an officer. Although formidably armed, the shelfae chieftain prefers to bring its opponents down first by sweeping its tail to produce a quake effect."
    ],
    arrival: [
      "A shelfae chieftain just arrived."
    ],
    flee: [
      "A shelfae chieftain runs {direction}."
    ],
    death: [
      "The shelfae chieftain falls to the ground and dies.",
      "The shelfae chieftain screams one last time and dies.",
      "The shelfae chieftain twitches violently, then dies."
    ],
    decay: [
      "A chieftain crumbles into dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A shelfae chieftain swings {weapon} at you!"
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
