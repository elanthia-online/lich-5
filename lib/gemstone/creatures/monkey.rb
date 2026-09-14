{
  schema_version: 3,
  name: "monkey",
  noun: "monkey",
  url: "https://gswiki.play.net/monkey",
  picture: "",
  level: 6,
  family: "Primate",
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
  max_hp: 86,
  speed: 9,
  height: 2,
  size: "small",
  areas: [
    {
      name: "The Citadel",
      uids: [377051..377066, 377077..377081, 377083..377084]
    },
    {
      name: "Muddy Village",
      uids: [7128001..7128015, 7128026..7128030]
    },
    {
      name: "unmapped",
      uids: [377067..377076, 377082..377082, 7128016..7128025]
    },
    {
      name: "Thurfel's Island",
      uids: [7530006..7530029]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 88
      },
      {
        name: "Mace"
      },
      {
        name: "Closed fist",
        as: 88
      },
      {
        name: "Leather whip"
      },
      {
        name: "Length of coiled red vine",
        as: 70
      },
      {
        name: "Thin oaken cudgel",
        as: 63
      },
      {
        name: "Iron-tipped wooden cane",
        as: 70
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Hide"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "1",
    immunities: [],
    melee: (32..123),
    ranged: (31..43),
    bolt: (31..43),
    udf: (54..144),
    bar_td: 18,
    cle_td: 18,
    emp_td: 18,
    pal_td: (15..18),
    ran_td: 18,
    sor_td: 18,
    wiz_td: nil,
    mje_td: 18,
    mne_td: 18,
    mjs_td: (18..24),
    mns_td: (18..24),
    mnm_td: 18,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bright gold-buttoned coat",
    "a jaunty yellow bowtie",
    "a length of coiled red vine",
    "a long flowing red evening gown",
    "a strand of faux pearls",
    "a striped silver-clasped coat",
    "a tall dark felt hat",
    "a thin oaken cudgel",
    "a vibrant yellow jacket",
    "a wide-brimmed yellow hat",
    "an iron-tipped wooden cane",
    "some sensible red boots"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a monkey paw",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      ""
    ],
    arrival: [
      "A monkey scampers in!",
      "A monkey scampers in at a reckless tear!",
      "A deep pink monkey scampers in at a reckless tear!",
      "A deep pink monkey scampers in!",
      "A brilliant violet monkey scampers in!",
      "A brilliant violet monkey scampers in at a reckless tear!",
      "A stout bright orange {pronoun} scampers in at a reckless tear!",
      "A bright green monkey scampers in at a reckless tear!",
      "A bright green monkey scampers in!",
      "A stout bright orange {pronoun} scampers in!",
      "A stout bright orange monkey scampers in at a reckless tear!",
      "A stout bright orange monkey scampers in!"
    ],
    flee: [
      "A monkey scampers {direction}.",
      "A deep pink monkey scampers {direction}.",
      "A brilliant violet monkey scampers {direction}.",
      "A deep pink monkey scampers out of sight!",
      "A stout bright orange {pronoun} scampers {direction}.",
      "A bright green monkey scampers {direction}.",
      "A stout bright orange {pronoun} scampers out of sight!",
      "A monkey scampers out of sight!",
      "A bright green monkey scampers out of sight!",
      "A brilliant violet monkey scampers out of sight!",
      "A stout bright orange monkey scampers {direction}.",
      "A stout bright orange monkey scampers out of sight!",
      "A monkey just went through a cage door.",
      "A monkey raises {pronoun} tail as {pronoun} slowly backs away."
    ],
    death: [
      "The monkey screeches one last time and dies.",
      "The monkey falls back into a heap and dies.",
      "The pink monkey falls back into a heap and dies.",
      "The pink monkey screeches one last time and dies.",
      "The pink monkey struggles to rise, then shudders and dies.",
      "The violet monkey falls back into a heap and dies.",
      "The violet monkey screeches one last time and dies.",
      "The green monkey falls back into a heap and dies.",
      "The orange monkey falls back into a heap and dies.",
      "The green monkey screeches one last time and dies.",
      "The orange monkey screeches one last time and dies."
    ],
    decay: [
      "A monkey decays into compost.",
      "A deep pink monkey decays into compost.",
      "A brilliant violet monkey decays into compost.",
      "A bright green monkey decays into compost.",
      "A stout bright orange {pronoun} decays into compost.",
      "A stout bright orange monkey decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A monkey swings {weapon} at you!",
        "A monkey leaps onto you and pokes your eyes! While rubbing your eyes you hear a monkey scramble off.",
        "A monkey leaps out of hiding!",
        "A monkey swings a war hammer at {target}!"
      ],
      bite: [
        "A monkey tries to bite you!"
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
