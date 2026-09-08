{
  schema_version: 3,
  name: "shan empath",
  noun: "empath",
  url: "https://gswiki.play.net/shan_empath",
  picture: "",
  level: 60,
  family: "Shan",
  type: "Biped",
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
  max_hp: 238,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Forgotten Vineyard",
      uids: [4225003..4225016]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Spirit Strike"
      },
      {
        name: "Modwir-hafted mace",
        as: (260..378)
      }
    ],
    maneuvers: [
      {
        name: "Gesture"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (205..446),
    ranged: (184..295),
    bolt: (184..295),
    udf: (269..445),
    bar_td: nil,
    cle_td: (277..283),
    emp_td: (271..286),
    pal_td: (240..249),
    ran_td: (216..228),
    sor_td: (254..276),
    wiz_td: nil,
    mje_td: (270..279),
    mne_td: (270..279),
    mjs_td: 295,
    mns_td: 295,
    mnm_td: (206..215),
    defensive_spells: [
      "Troll's Blood"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a modwir-hafted mace",
    "an engraved parma",
    "some torn leathers"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "n'ayanad crystal",
      "ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    attacks: {
      attack: [
        "A shan empath snarls and gestures sharply at you!",
        "A shan empath swings {weapon} at you!"
      ],
      bolt: [
        "A shan empath hurls a radiant ball of energy at you!"
      ]
    },
    stand: [
      "A shan empath scrambles to {pronoun} feet!"
    ],
    description: [
      ""
    ],
    arrival: [
      "A shan empath just arrived.",
      "A shan empath plods in snarling to the spirits!",
      "A shan empath just came through a rotting gate leading down to a vineyard."
    ],
    flee: [
      "A shan empath pads {direction}.",
      "A shan empath limps {direction}.",
      "A shan empath just went into a decrepit gazebo.",
      "A shan empath just went through a rotting gate leading down to a vineyard.",
      "A shan empath just went into a dark tunnel.",
      "A shan empath just went through a rotting gate leading up to the overlook."
    ],
    death: [
      "The shan empath howls out one last time and dies.",
      "The shan empath yips in pain as {pronoun} falls to the ground motionless.",
      "A shan empath's body shimmers slightly.  Suddenly, {pronoun} features cave in, falling grotesquely into a haunting visage of decay, before abruptly fraying to a pile of fur and fangs that marks the spot of {pronoun} death like a silhouette."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A shan empath concentrates intently on you, and a pulse of pearlescent energy ripples toward you!"
    ],
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
