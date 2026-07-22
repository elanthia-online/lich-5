{
  schema_version: 3,
  name: "crested basilisk",
  noun: "",
  url: "https://gswiki.play.net/crested_basilisk",
  picture: "",
  level: 22,
  family: "Basilisk",
  type: "Hybrid",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 200,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Outlands",
      rooms: []
    },
    {
      name: "Rambling Meadows",
      rooms: []
    },
    {
      name: "Yegharren Plains",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 220
      },
      {
        name: "Claw",
        as: (208..216)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Paralyzing Gaze"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: 127,
    ranged: (129..145),
    bolt: 129,
    udf: 149,
    bar_td: (66..72),
    cle_td: nil,
    emp_td: 68,
    pal_td: nil,
    ran_td: nil,
    sor_td: 70,
    wiz_td: 72,
    mje_td: nil,
    mne_td: (72..78),
    mjs_td: 68,
    mns_td: 68,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: nil,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: "a basilisk crest",
    other: nil
  },
  messaging: {
    description: [
      "The crested basilisk is the size of a large dog, but its vicious-looking talons and sharp, hooked beak are fearsome weapons indeed. Looking like a cross between a huge fighting rooster and a serpentine lizard, the crested basilisk gazes around with its hypnotic, paralyzing eyes as its scaled reptilian tail whips back and forth. A bright red crest, more reminiscent of a lizard than of a chicken, adorns its feathered head and neck."
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
