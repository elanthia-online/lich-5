{
  schema_version: 3,
  name: "giant albino scorpion",
  noun: "scorpion",
  url: "https://gswiki.play.net/giant_albino_scorpion",
  picture: "",
  level: 24,
  family: "Arachnid",
  type: "Arachnid",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: nil,
  muggable: true,
  sleepable: true,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 212,
  speed: 7,
  height: 1,
  size: "medium",
  areas: [
    {
      name: "Mraent Caverns",
      uids: [13008001..13008040]
    },
    {
      name: "unmapped",
      uids: [13008041..13008041]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pincer (attack)",
        as: 197
      },
      {
        name: "Stinger (attack)",
        as: 207
      },
      {
        name: "Pincer",
        as: (157..177)
      },
      {
        name: "Stinger",
        as: 207
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
    melee: (138..219),
    ranged: (133..172),
    bolt: (133..172),
    udf: (140..220),
    bar_td: 72,
    cle_td: (68..74),
    emp_td: (73..76),
    pal_td: (66..75),
    ran_td: (66..72),
    sor_td: (79..85),
    wiz_td: nil,
    mje_td: (78..82),
    mne_td: (78..82),
    mjs_td: (76..99),
    mns_td: (76..99),
    mnm_td: 72,
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
    skin: "a scorpion stinger",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The scorpion is like any other scorpion in general body structure. This particular variety, however, is about seven feet in length, with potent venom brewing in its cauda. The huge insectoid creature is entirely white, except for its pincers and stinger, which are a light pink. The eyes of the albino scorpion are crimson -- not to mention entirely blind."
    ],
    arrival: [],
    flee: [
      "A giant albino scorpion skitters {direction}.",
      "A giant albino scorpion skitters south with delicate appendages.",
      "A giant albino scorpion skitters down with delicate appendages.",
      "A giant albino scorpion skitters west with delicate appendages.",
      "A giant albino scorpion skitters east with delicate appendages.",
      "A giant albino scorpion skitters up with delicate appendages.",
      "A giant albino scorpion skitters north with delicate appendages.",
      "A giant albino scorpion skitters northwest with delicate appendages.",
      "A giant albino scorpion skitters northeast with delicate appendages."
    ],
    death: [
      "The albino scorpion twitches violently, then dies.",
      "A giant albino scorpion collapses, leaving behind a hollow exoskeleton.",
      "A giant albino scorpion falls to the ground with an echoing clatter, dead."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A giant albino scorpion snaps at you with {pronoun} pincer!",
        "A giant albino scorpion stabs at you with {pronoun} stinger!",
        "A giant albino scorpion lashes out wildly with {pronoun} stinger, hitting only air."
      ],
      bite: [
        "A giant albino scorpion snaps at you with {pronoun} pincer!"
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
