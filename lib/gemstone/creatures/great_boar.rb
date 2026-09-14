{
  schema_version: 3,
  name: "great boar",
  noun: "boar",
  url: "https://gswiki.play.net/great_boar",
  picture: "",
  level: 10,
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
  max_hp: 100,
  speed: 15,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Vornavian Coast",
      uids: [4202182..4202199]
    },
    {
      name: "Yander's Farm",
      uids: [14005054..14005066]
    },
    {
      name: "Lysierian Hills",
      uids: [92002..92018]
    },
    {
      name: "Slope",
      uids: [395002..395015]
    },
    {
      name: "Locksmehr Trail",
      uids: [13000002..13000047]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge",
        as: (138..148)
      },
      {
        name: "Bite",
        as: (128..138)
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
    special_abilities: [
      {
        name: "Charge"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (31..79),
    ranged: (10..29),
    bolt: (10..29),
    udf: (63..113),
    bar_td: 30,
    cle_td: 30,
    emp_td: 30,
    pal_td: (27..30),
    ran_td: 30,
    sor_td: 30,
    wiz_td: nil,
    mje_td: 30,
    mne_td: 30,
    mjs_td: (45..54),
    mns_td: (45..54),
    mnm_td: 30,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: [
      "Hides when attacked"
    ]
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
    skin: "a boar tusk",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The great boar snorts loudly and scrapes at the ground, peering around with his close-set, bloodshot eyes in hopes of finding something he can gore into a bloody pulp or pound into the earth. His body is covered with coarse, mottled, grey-brown hair, and gleaming tusks protrude from each side of his gaping mouth. A good six feet long from dripping snout to curly tail and weighing more than a quarter ton, the great boar moves with surprising speed and dexterity as he bears down, squealing furiously, on his intended prey. This is one mean brute."
    ],
    arrival: [
      "A great boar charges in, grunting an angry challenge!",
      "A great boar barrels in!"
    ],
    flee: [
      "A great boar grunts and barrels {direction}.",
      "A great boar trots {direction}, grunting noisily.",
      "A great boar grunts as {pronoun} slowly backs away."
    ],
    death: [
      "The great boar collapses to the ground, emits a final squeal, and dies.",
      "The great boar lets out a final agonized squeal and dies.",
      "The great boar collapses to the ground, emits a final silent squeal, and dies.",
      "The great boar silently lets out a final agonized squeal and dies."
    ],
    decay: [
      "A great boar decays into a pile of fur and bone."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A great boar charges at you!",
        "A great boar charges towards you, but you leap to the side at the last instant, avoiding a gruesome fate! The great boar stumbles and falls!"
      ],
      bite: [
        "A great boar tries to bite you!"
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
