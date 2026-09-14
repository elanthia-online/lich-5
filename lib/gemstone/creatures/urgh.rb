{
  schema_version: 3,
  name: "urgh",
  noun: "urgh",
  url: "https://gswiki.play.net/urgh",
  picture: "",
  level: 4,
  family: "Suine",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
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
  max_hp: 51,
  speed: 15,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Foothills of Zeltoph",
      uids: [2131013..2131024]
    },
    {
      name: "Plains of Vornavis",
      uids: [4212101..4212130, 4213101..4213130]
    },
    {
      name: "Noman's Land",
      uids: [4600001..4600009]
    },
    {
      name: "Locksmehr Trail",
      uids: [13001001..13001038]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Impale",
        as: 84
      },
      {
        name: "Tusk",
        as: 74
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
    melee: (21..51),
    ranged: 19,
    bolt: 19,
    udf: (49..72),
    bar_td: 12,
    cle_td: 12,
    emp_td: 12,
    pal_td: (9..12),
    ran_td: 12,
    sor_td: 12,
    wiz_td: nil,
    mje_td: 12,
    mne_td: 12,
    mjs_td: (12..15),
    mns_td: (12..15),
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
    skin: "urgh hide",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The herbivorous urgh resembles, if anything, an overgrown, hairy pig. He stands on four feet and has a dark brown coat and curled, hairless tail. Instead of the usual upper and lower jaw in the front of his head, though, the urgh has an extremely long upper lip, which he can extend a good two feet to drag vegetation back into his mouth. Under the mouth reside two long, sharp tusks, used for digging up peat and other grasses upon which the urgh feeds, and for defense."
    ],
    arrival: [
      "An urgh charges in, squealing an angry challenge!"
    ],
    flee: [
      "An urgh trots {direction}.",
      "An urgh squeals as {pronoun} slowly backs away."
    ],
    death: [
      "The urgh collapses to the ground, emits a final squeal, and dies.",
      "The urgh lets out a final agonized squeal and dies."
    ],
    decay: [
      "An urgh decays into a pile of fur and bone."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "An urgh charges at you with {pronoun} tusk!",
        "An urgh charges at {target} with {pronoun} tusk!"
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
