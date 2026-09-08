{
  schema_version: 3,
  name: "siren lizard",
  noun: "lizard",
  url: "https://gswiki.play.net/siren_lizard",
  picture: "",
  level: 42,
  family: "Reptilian",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 400,
  speed: 8,
  height: 2,
  size: "large",
  areas: [
    {
      name: "Fhorian Village",
      uids: [3030035..3030039, 3030211..3030219, 3030221..3030234, 3030250..3030255]
    },
    {
      name: "unmapped",
      uids: [3030220..3030220]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "claw (attack)",
        as: 267
      },
      {
        name: "Pound (attack)",
        as: 267
      },
      {
        name: "Ensnare (attack)",
        as: 277
      },
      {
        name: "Tail (attack)",
        as: 255
      },
      {
        name: "Claw",
        as: 267
      },
      {
        name: "Ensnare",
        as: 277
      },
      {
        name: "Fist",
        as: 267
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Poison",
        cs: 126
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Tail lash"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (154..194),
    ranged: (153..203),
    bolt: (153..203),
    udf: 248,
    bar_td: 137,
    cle_td: 151,
    emp_td: 150,
    pal_td: (124..127),
    ran_td: 127,
    sor_td: 159,
    wiz_td: nil,
    mje_td: (167..275),
    mne_td: (167..275),
    mjs_td: 184,
    mns_td: 184,
    mnm_td: 126,
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
    magic_items: true,
    gems: true,
    boxes: nil,
    skin: "a multicolored siren lizard skin",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The siren lizard has multicolored pastel skin which appears to be rather scaly, a long, blunt snout, sharp teeth, and a swiftly moving tail."
    ],
    arrival: [
      "A siren lizard just arrived.",
      "A siren lizard charges in."
    ],
    flee: [
      "A siren lizard heads {direction}.",
      "A siren lizard just went across a footbridge.",
      "A siren lizard just went into a storage building.",
      "A siren lizard just went into a warehouse."
    ],
    death: [
      "The siren lizard falls to the ground and dies.",
      "The siren lizard hisses one last time and dies.",
      "The siren lizard twitches violently, then dies."
    ],
    decay: [
      "A siren lizard decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A siren lizard pounds at you with {pronoun} fist!",
        "A siren lizard swings {pronoun} swift tail at you!",
        "A siren lizard tries to ensnare you!",
        "A siren lizard lashes {pronoun} tail with lightning speed at your legs!",
        "A siren lizard pounds at {target} with {pronoun} fist!"
      ],
      claw: [
        "A siren lizard claws at you!"
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
