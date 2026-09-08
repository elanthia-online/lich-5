{
  schema_version: 3,
  name: "ridgeback boar",
  noun: "boar",
  url: "https://gswiki.play.net/ridgeback_boar",
  picture: "",
  level: 15,
  family: "Suine",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
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
  max_hp: 140,
  speed: 9,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Yegharren Plains",
      uids: [13034203..13034214, 13034324..13034336, 13034401..13034416]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge",
        as: (140..170)
      },
      {
        name: "Bite",
        as: (160..170)
      },
      {
        name: "Impale",
        as: 170
      },
      {
        name: "Tusk",
        as: 150
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Charge maneuver"
      },
      {
        name: "Charge"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (36..95),
    ranged: (18..48),
    bolt: (18..48),
    udf: (54..97),
    bar_td: 45,
    cle_td: 45,
    emp_td: (45..53),
    pal_td: (39..48),
    ran_td: (39..51),
    sor_td: (42..51),
    wiz_td: nil,
    mje_td: (42..45),
    mne_td: (42..45),
    mjs_td: 63,
    mns_td: 63,
    mnm_td: (45..51),
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
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "a yellowed boar tusk",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The ridgeback boar snorts loudly and scrapes at the ground, peering around with his close-set, bloodshot eyes in hopes of finding something he can gore into a bloody pulp or pound into the earth. His body is covered with coarse, reddish-brown hair, and gleaming tusks protrude from each side of his gaping mouth. A good eight feet long from dripping snout to curly tail and weighing nearly a half ton, the ridgeback boar moves with surprising speed and dexterity as he bears down, squealing furiously, on his intended prey. The boar's bony backbone lends the beast his name, as it juts up through his bristly hair."
    ],
    arrival: [
      "A ridgeback boar charges in, grunting an angry challenge!",
      "A ridgeback boar barrels in!"
    ],
    flee: [
      "A ridgeback boar crawls {direction}.",
      "A ridgeback boar grunts and barrels {direction}.",
      "A ridgeback boar trots {direction}, grunting noisily!",
      "A ridgeback boar trots {direction}, grunting noisily.",
      "A ridgeback boar grunts as {pronoun} slowly backs away."
    ],
    death: [
      "The ridgeback boar collapses to the ground, emits a final squeal, and dies.",
      "The ridgeback boar lets out a final agonized squeal and dies.",
      "The ridgeback boar silently lets out a final agonized squeal and dies.",
      "The ridgeback boar collapses to the ground, emits a final silent squeal, and dies."
    ],
    decay: [
      "A ridgeback boar decays into a pile of fur and bone."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A ridgeback boar charges at you with {pronoun} tusk!",
        "A ridgeback boar charges at you!",
        "A ridgeback boar charges at {target} with {pronoun} tusk!",
        "A ridgeback boar charges towards you, but you leap to the side at the last instant, avoiding a gruesome fate! The ridgeback boar stumbles and falls!"
      ],
      bite: [
        "A ridgeback boar tries to bite you!"
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
