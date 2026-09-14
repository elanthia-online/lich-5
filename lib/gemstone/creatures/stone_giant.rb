{
  schema_version: 3,
  name: "stone giant",
  noun: "giant",
  url: "https://gswiki.play.net/stone_giant",
  picture: "",
  level: 58,
  family: "Giant",
  type: "Biped",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: nil,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 600,
  speed: 11,
  height: 22,
  size: "huge",
  areas: [
    {
      name: "Stone Valley",
      uids: [4291027..4291043, 4291046..4291050, 4291053..4291058, 4292001..4292060]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound"
      },
      {
        name: "Stomp"
      },
      {
        name: "War mattock",
        as: 324
      },
      {
        name: "Large rock",
        as: 267
      }
    ],
    bolt_spells: [
      {
        name: "Hurl Boulder (510)",
        as: 334
      }
    ],
    warding_spells: [
      {
        name: "Unbalance (110)",
        cs: (251..263)
      }
    ],
    offensive_spells: [
      {
        name: "Earthen Fury (917)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "20N",
    immunities: [],
    melee: (149..573),
    ranged: (110..222),
    bolt: (110..222),
    udf: (301..474),
    bar_td: 202,
    cle_td: (219..222),
    emp_td: 228,
    pal_td: (186..195),
    ran_td: (192..198),
    sor_td: (235..241),
    wiz_td: nil,
    mje_td: (240..243),
    mne_td: (240..243),
    mjs_td: (261..268),
    mns_td: (261..268),
    mnm_td: (177..187),
    defensive_spells: [
      "Natural Colors",
      "Resist Elements",
      "Self Control"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a war mattock"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "essence of earth",
      "glowing violet mote of essence"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Looming high above you, taller than three of the tallest giantmen, this stone giant dominates the surrounding area. The stone giant's skin is a smooth dull grey with mottled brown splotches and its eyes, concealed under a heavy brow, gleam black with hatred."
    ],
    arrival: [
      "A stone giant just arrived.",
      "The ground shakes as an enraged stone giant stomps in!",
      "A stone giant just came through an enormous arched doorway."
    ],
    flee: [
      "A stone giant crawls {direction}.",
      "A stone giant sinks into the ground and tunnels {direction}."
    ],
    death: [
      "The stone giant rumbles in agony and goes still.",
      "The stone giant shudders and goes still.",
      "The stone giant falls to the floor dead, {pronoun} stone hide still pulsating with a blinding white hue."
    ],
    decay: [
      "A stone giant sinks into the ground, leaving nothing behind."
    ],
    search: [],
    spell_prep: [
      "A stone giant rumbles an incantation."
    ],
    stand: [
      "A stone giant throws {pronoun} head back and roars, shaking off the stun!",
      "A stone giant throws {pronoun} head back and roars silently, shaking off the stun!"
    ],
    attacks: {
      attack: [
        "A stone giant swings {weapon} at you!",
        "The stone giant rumbles in agony as {pronoun} teeters for a moment, then falls directly at you!",
        "A stone giant swings a war mattock at {target}!"
      ],
      hurl: [
        "A stone giant throws {weapon} at you!"
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
