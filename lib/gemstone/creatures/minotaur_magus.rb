{
  schema_version: 3,
  name: "minotaur magus",
  noun: "",
  url: "https://gswiki.play.net/minotaur_magus",
  picture: "",
  level: 78,
  family: "Minotaur",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 250,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Wehntoph",
      rooms: []
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
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "11",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: 259,
    ran_td: nil,
    sor_td: (268..317),
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
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
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a minotaur hoof",
    other: "[[Tiny golden seed]]"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The minotaur magus is an ugly, brutish looking beast.  Taller than most average men, the minotaur has a bull-like appearance while his muscular body is humanoid with thick arms and broad shoulders.  The minotaur magi feet end in hooves that rattle the ground with every step.  Despite his barbaric features, a great intelligence is reflected in the depths of his eyes and mannerisms.</pre>"
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
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
