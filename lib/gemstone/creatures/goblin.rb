{
  schema_version: 3,
  name: "goblin",
  noun: "",
  url: "https://gswiki.play.net/goblin",
  picture: "",
  level: 2,
  family: "Goblin",
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
  max_hp: 40,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Old Mine Road",
      rooms: []
    },
    {
      name: "The Graveyard",
      rooms: []
    },
    {
      name: "Upper Trollfang",
      rooms: []
    },
    {
      name: "Wehnimer's Environs",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Flail",
        as: 46
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
    asg: "5",
    immunities: [],
    melee: 54,
    ranged: nil,
    bolt: 6,
    udf: 36,
    bar_td: 6,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 6,
    wiz_td: nil,
    mje_td: 6,
    mne_td: 6,
    mjs_td: nil,
    mns_td: 6,
    mnm_td: nil,
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
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: "a goblin skin",
    other: nil
  },
  messaging: {
    description: [
      "Round-headed with a squat nose and a wide mouth, the goblin has greenish skin with a sickly yellow cast over all. Roughly as tall as a dwarf or halfling, the goblin moves with a nervous energy but rarely looks directly at you. A yeasty smell as of molding bread or of something left to rot in a dark damp place completes the goblin's aura of repulsivenss."
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
