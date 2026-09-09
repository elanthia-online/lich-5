{
  schema_version: 3,
  name: "krolvin warrior",
  noun: "warrior",
  url: "https://gswiki.play.net/krolvin_warrior",
  picture: "",
  level: 19,
  family: "Krolvin",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 220,
  speed: 9,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Sea Caves",
      uids: [26002..26036, 26103..26120]
    },
    {
      name: "Lysierian Hills",
      uids: [93057..93079]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "War mattock",
        as: (156..195)
      },
      {
        name: "Morning star",
        as: (166..195)
      },
      {
        name: "Jeddart-axe",
        as: 185
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
    asg: "12",
    immunities: [],
    melee: (124..224),
    ranged: (119..168),
    bolt: (119..168),
    udf: (107..201),
    bar_td: 57,
    cle_td: (51..60),
    emp_td: (57..65),
    pal_td: (54..63),
    ran_td: (54..63),
    sor_td: (57..63),
    wiz_td: nil,
    mje_td: (57..63),
    mne_td: (57..63),
    mjs_td: (54..63),
    mns_td: (54..63),
    mnm_td: (57..63),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a chain hauberk",
    "a cracked leather belt",
    "a jeddart-axe",
    "a morning star",
    "a reinforced shield",
    "a war mattock",
    "some brigandine armor"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "s'ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "As tall as the average human, the warrior has the characteristic long-fingered hands and sturdy musculature that denote most of the krolvin race. The warrior also sports the trademark grey-blue skin and thick, coarse, white hair covers his head and spreads across his shoulders and down his back."
    ],
    arrival: [
      "A krolvin warrior just came through a high opening."
    ],
    flee: [
      "A krolvin warrior stumps {direction}.",
      "A gleaming krolvin warrior stumps {direction}.",
      "A shimmering krolvin warrior stumps {direction}.",
      "A krolvin warrior just went through a high opening."
    ],
    death: [
      "The krolvin warrior rolls over on the floor and goes still.",
      "The krolvin warrior rolls over on the ground and goes still.",
      "The krolvin warrior falls lifeless to the floor with a heavy thump."
    ],
    decay: [
      "A krolvin warrior's body decays into a pile of compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A krolvin warrior swings {weapon} at you!",
        "A krolvin warrior's face contorts as {pronoun} unleashes a gutteral, deep-throated growl at you!"
      ],
      bite: [
        "A krolvin warrior gnaws idly at {pronoun} arm."
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
