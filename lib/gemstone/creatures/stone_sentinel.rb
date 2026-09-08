{
  schema_version: 3,
  name: "stone sentinel",
  noun: "sentinel",
  url: "https://gswiki.play.net/stone_sentinel",
  picture: "",
  level: 53,
  family: "Golem",
  type: "Biped",
  undead: false,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: false,
  sympathy: true,
  muggable: nil,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Magical"
  ],
  bcs: true,
  max_hp: 331,
  speed: 8,
  height: 8,
  size: "large",
  areas: [
    {
      name: "Darkstone Castle",
      uids: [42001..42016, 42024..42026]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound",
        as: 380
      },
      {
        name: "Fist",
        as: (350..380)
      }
    ],
    bolt_spells: [
      {
        name: "Fireball",
        as: 373
      }
    ],
    warding_spells: [
      {
        name: "Mind Jolt",
        cs: (231..241)
      },
      {
        name: "Silence",
        cs: (231..241)
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Earthen Fury (917)"
      }
    ],
    maneuvers: [
      {
        name: "Point"
      }
    ],
    special_abilities: [
      {
        name: "Stone-spitting"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "20",
    immunities: [
      "Stun"
    ],
    melee: (23..109),
    ranged: (27..113),
    bolt: (27..113),
    udf: (294..446),
    bar_td: nil,
    cle_td: (202..212),
    emp_td: (203..213),
    pal_td: (184..194),
    ran_td: (174..184),
    sor_td: (216..226),
    wiz_td: nil,
    mje_td: 235,
    mne_td: 235,
    mjs_td: (203..213),
    mns_td: (203..213),
    mnm_td: (180..190),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a blinded left eye",
    "a bruised right eye"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "crystal core",
      "essence of earth"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Comprised of solid blocks of granite, the immense stone sentinel stands and moves very stiffly. Each portion of its anatomy is chiseled in rectangular pieces with sharp right angles. It is not apparent how this animated construct moves, or how it even stays together, but somehow it does both effectively. The attacks of a stone sentinel carry the weight of tons of rock behind them. Being in the path of one is not an experience to be recommended."
    ],
    arrival: [
      "A stone sentinel just arrived."
    ],
    flee: [
      "A stone sentinel heads {direction}."
    ],
    death: [],
    decay: [
      "A stone sentinel crumbles to dust."
    ],
    search: [
      "A stone sentinel scans the area slowly and carefully."
    ],
    spell_prep: [
      "A stone sentinel traces a circle in the air."
    ],
    attacks: {
      attack: [
        "A stone sentinel pounds at you with {pronoun} fist!",
        "A stone sentinel points at you!",
        "A stone sentinel pounds at a stone sentinel with {pronoun} fist!",
        "A stone sentinel pounds at {target} with {pronoun} fist!",
        "A stone sentinel exhales a virulent green mist toward you, but you are unaffected.",
        "A stone sentinel opens {pronoun} mouth and spits a stone at you."
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
