{
  schema_version: 3,
  name: "muddy hog",
  noun: "hog",
  url: "https://gswiki.play.net/muddy_hog",
  picture: "",
  level: nil,
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
  otherclass: [],
  bcs: true,
  max_hp: 131,
  speed: 15,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Black Weald",
      uids: [7130001..7130018]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 161
      },
      {
        name: "Charge",
        as: 171
      },
      {
        name: "Unknown",
        as: 171
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
    asg: nil,
    immunities: [],
    melee: (65..67),
    ranged: (65..67),
    bolt: (65..67),
    udf: (85..128),
    bar_td: nil,
    cle_td: (39..48),
    emp_td: (21..51),
    pal_td: (36..48),
    ran_td: 42,
    sor_td: (39..48),
    wiz_td: nil,
    mje_td: 42,
    mne_td: 42,
    mjs_td: (36..48),
    mns_td: (36..48),
    mnm_td: (42..48),
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
    skin: "brown boar hide",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      ""
    ],
    arrival: [
      "A muddy hog barrels in!",
      "A muddy hog trots in!"
    ],
    flee: [
      "A muddy hog trots {direction}.",
      "A muddy hog grunts as {pronoun} slowly backs away."
    ],
    death: [
      "The muddy hog collapses to the ground, emits a final squeal, and dies.",
      "The muddy hog lets out a final agonized squeal and dies.",
      "The muddy hog collapses to the ground, emits a final silent squeal, and dies."
    ],
    decay: [
      "A muddy hog decays into a pile of fur and bone."
    ],
    search: [
      "A muddy hog sniffs the air anxiously.",
      "A muddy hog glances around, sure that {pronoun} has missed something..."
    ],
    spell_prep: [],
    attacks: {
      attack: [
        "A muddy hog charges at you!"
      ],
      bite: [
        "A muddy hog tries to bite you!"
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
