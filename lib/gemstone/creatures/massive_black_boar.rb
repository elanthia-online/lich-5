{
  schema_version: 3,
  name: "massive black boar",
  noun: "boar",
  url: "https://gswiki.play.net/massive_black_boar",
  picture: "",
  level: 59,
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
  max_hp: 400,
  speed: 9,
  height: 4,
  size: "large",
  areas: [
    {
      name: "Blighted Forest",
      uids: [13020001..13020051]
    },
    {
      name: "Red Forest",
      uids: [480201..480215, 17006201..17006215]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge (attack)",
        as: 335
      },
      {
        name: "Impale (attack)",
        as: 292
      },
      {
        name: "Bite (attack)",
        as: 312
      },
      {
        name: "Bite",
        as: 325
      },
      {
        name: "Charge",
        as: 335
      },
      {
        name: "Tusk",
        as: 325
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Charge"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (141..438),
    ranged: (219..259),
    bolt: (219..259),
    udf: (295..415),
    bar_td: (194..215),
    cle_td: 235,
    emp_td: (220..229),
    pal_td: (181..190),
    ran_td: (190..202),
    sor_td: (234..246),
    wiz_td: nil,
    mje_td: (246..256),
    mne_td: (246..256),
    mjs_td: (222..232),
    mns_td: (222..232),
    mnm_td: (177..183),
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
    skin: "a heavy grey tusk",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The black boar snorts loudly and scrapes at the ground, peering around with his close-set, bloodshot eyes in hopes of finding something he can gore into a bloody pulp or pound into the earth. His body is covered with coarse, black hair, and dull grey tusks protrude from each side of his gaping mouth. A good ten feet long from dripping snout to curly tail and weighing more than a ton, the black boar moves with surprising speed and dexterity as he bears down, squealing furiously, on his intended prey. The murderous glint in the boar's eyes betrays an intelligence much greater than his mundane kin."
    ],
    arrival: [
      "A massive black boar charges in, grunting an angry challenge!",
      "A massive black boar barrels in!"
    ],
    flee: [
      "A massive black boar crawls {direction}.",
      "A massive black boar grunts and barrels {direction}.",
      "A massive black boar trots {direction}, grunting noisily.",
      "A massive black boar trots {direction}, grunting noisily!",
      "A massive black boar grunts as {pronoun} slowly backs away."
    ],
    death: [
      "The black boar lets out a final agonized squeal and dies.",
      "The black boar collapses to the ground, emits a final squeal, and dies."
    ],
    decay: [
      "A massive black boar decays into a pile of fur and bone."
    ],
    search: [
      "A massive black boar cocks {pronoun} head and peers about suspiciously."
    ],
    spell_prep: [],
    attacks: {
      attack: [
        "A massive black boar charges at you with {pronoun} tusk!",
        "A massive black boar charges at you!",
        "A massive black boar charges at {target} with {pronoun} tusk!",
        "A massive black boar charges towards you, but you leap to the side at the last instant, avoiding a gruesome fate! The black boar stumbles and falls!"
      ],
      bite: [
        "A massive black boar tries to bite you!"
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
