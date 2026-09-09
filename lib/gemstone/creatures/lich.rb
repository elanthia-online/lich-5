{
  schema_version: 3,
  name: "lich",
  noun: "lich",
  url: "https://gswiki.play.net/lich",
  picture: "",
  level: 110,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead",
    "Extraplanar"
  ],
  bcs: true,
  max_hp: 238,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Rift",
      uids: [4571003..4571004, 4571016..4571021, 4571026..4571030]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Runestaff",
        as: 466
      },
      {
        name: "Crystal-set smooth ironwood scepter",
        as: 466
      },
      {
        name: "Barbed tentacle",
        as: 430
      },
      {
        name: "Bladed forearms",
        as: 487
      }
    ],
    bolt_spells: [
      {
        name: "Major Cold (907)",
        as: 422
      }
    ],
    warding_spells: [
      {
        name: "Cold Snap (512)",
        cs: 500
      },
      {
        name: "Dark Catalyst (719)",
        cs: (477..489)
      },
      {
        name: "Burrow Ambush",
        cs: 477
      }
    ],
    offensive_spells: [
      {
        name: "Major Elemental Wave (435)"
      },
      {
        name: "Tremors (909)"
      },
      {
        name: "Elemental Disjunction (530)"
      }
    ],
    maneuvers: [
      {
        name: "Point"
      },
      {
        name: "Lash"
      },
      {
        name: "Pounce"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: 661,
    ranged: nil,
    bolt: 550,
    udf: 721,
    bar_td: 439,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: (376..391),
    sor_td: 493,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a crystal-set smooth ironwood scepter",
    "an ancient gnarled bone phylactery",
    "some disheveled deep grey robes"
  ],
  treasure: {
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      ""
    ],
    arrival: [
      "An infernal lich strides in, leaving a scorched path in her wake.",
      "A frostborne lich strides in, leaving thin layer of frost in {pronoun} wake."
    ],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "An infernal {pronoun} assumes a wild-eyed expression as {pronoun} points a finger at you!",
        "A lich swings {weapon} at you!",
        "A frostborne {pronoun} assumes a wild-eyed expression as {pronoun} points a finger at you!"
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
