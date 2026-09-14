{
  schema_version: 3,
  name: "minotaur magus",
  noun: "magus",
  url: "https://gswiki.play.net/minotaur_magus",
  picture: "",
  level: 78,
  family: "Minotaur",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: nil,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 250,
  speed: nil,
  height: 8,
  size: "medium",
  areas: [
    {
      name: "The Hidden Plateau",
      uids: [2167070..2167108]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Runestaff",
        as: 336
      }
    ],
    bolt_spells: [
      {
        name: "Fire Spirit (111)",
        as: 379
      }
    ],
    warding_spells: [
      {
        name: "Divine Fury (317)",
        cs: 336
      }
    ],
    offensive_spells: [
      {
        name: "Heroism (215)"
      },
      {
        name: "Spirit Strike (117)"
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
    asg: "11",
    immunities: [],
    melee: (349..421),
    ranged: (236..376),
    bolt: (236..376),
    udf: (446..482),
    bar_td: nil,
    cle_td: (303..304),
    emp_td: 289,
    pal_td: (256..262),
    ran_td: (249..259),
    sor_td: (268..327),
    wiz_td: nil,
    mje_td: (327..335),
    mne_td: (327..335),
    mjs_td: (299..301),
    mns_td: (299..301),
    mnm_td: 266,
    defensive_spells: [
      "Spell Shield (219)",
      "Spirit Defense (103)",
      "Spirit Shield (202)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "an onyx-inset carved wooden runestaff",
    "some ebon-hued studded leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a minotaur hoof",
    other: "Tiny golden seed",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The minotaur magus is an ugly, brutish looking beast. Taller than most average men, the minotaur has a bull-like appearance while his muscular body is humanoid with thick arms and broad shoulders. The minotaur magi feet end in hooves that rattle the ground with every step. Despite his barbaric features, a great intelligence is reflected in the depths of his eyes and mannerisms."
    ],
    arrival: [],
    flee: [
      "A minotaur magus trots {direction}, whispering a silent prayer as {pronoun} passes.",
      "A minotaur magus trots {direction}, whispering a silent prayer."
    ],
    death: [],
    decay: [
      "The thick skin of a minotaur warrior falls in upon itself as his enormous form decays into a fine dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A minotaur magus swings an onyx-inset carved wooden runestaff at you!"
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
