{
  schema_version: 3,
  name: "stooped titan stormcaller",
  noun: "stormcaller",
  url: "https://gswiki.play.net/stooped_titan_stormcaller",
  picture: "",
  level: 81,
  family: "Giant",
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
  max_hp: 402,
  speed: nil,
  height: 12,
  size: "huge",
  areas: [
    {
      name: "Stormpeak",
      uids: [13150401..13150425]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Leering Lightning(?)"
      },
      {
        name: "Glowing hand",
        as: 205
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "2",
    immunities: [],
    melee: (412..531),
    ranged: (415..501),
    bolt: (415..501),
    udf: (389..477),
    bar_td: nil,
    cle_td: (325..334),
    emp_td: (334..344),
    pal_td: (293..303),
    ran_td: (296..306),
    sor_td: (335..365),
    wiz_td: nil,
    mje_td: (366..372),
    mne_td: (351..381),
    mjs_td: 364,
    mns_td: (319..349),
    mnm_td: (273..276),
    defensive_spells: [
      "Elemental Defense III (414)",
      "Elemental Barrier (430)",
      "Mage Armor (520)",
      "Mass Blur (911)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a burnt modwir staff inlaid with jagged brass lightning bolts",
    "a cream-colored homespun robe stitched with tiny disks of crude brass"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [],
    arrival: [
      "A gust of wind and a flash of lightning herald the arrival of a stooped titan stormcaller as {pronoun} lumbers in.",
      "A stooped titan stormcaller strides in, each step like a peal of thunder.",
      "A stooped titan stormcaller stiffly strides in, each step like a peal of thunder."
    ],
    flee: [],
    death: [
      "A ragged gasp fills a stooped titan stormcaller's lungs with a last breath that wooshes out as {pronoun} dies."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A stooped titan stormcaller mutters a thunderous chant as {pronoun} lifts {pronoun} eyes skyward.",
      "A stooped titan stormcaller gestures with a glowing hand at you!"
    ],
    attacks: {
      attack: [
        "A stooped titan stormcaller gestures with a glowing hand at you!",
        "A stooped titan stormcaller twirls {pronoun} modwir staff theatrically before lashing out at you!",
        "A stooped titan stormcaller throws {pronoun} head back and thunder peals through the air as a gust of wind stirs {pronoun} hair. {pronoun} lip curls cruelly as lightning arcs down {pronoun} limbs.",
        "A stooped titan stormcaller throws {pronoun} head back and thunder peals through the air as a gust of wind stirs {pronoun} hair. {target} lip curls cruelly as lightning arcs down {pronoun} limbs.",
        "A stooped titan stormcaller unleashes a bolt of churning air at you!"
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
