{
  schema_version: 3,
  name: "black forest ogre",
  noun: "",
  url: "https://gswiki.play.net/black_forest_ogre",
  picture: "",
  level: 60,
  family: "ogre",
  type: "Biped",
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
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Blighted Forest",
      rooms: []
    },
    {
      name: "Aradhul Road",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Dhara{{!}}Dhara (Rogues)",
        as: 340
      },
      {
        name: "Closed fist{{!}}Closed fist (Wizards)",
        as: 294
      }
    ],
    bolt_spells: [
      {
        name: "Hand of Tonis (505)",
        as: 379
      },
      {
        name: "Minor Acid (904)",
        as: 379
      },
      {
        name: "Minor Fire (906)",
        as: 379
      },
      {
        name: "Major Cold (907)",
        as: 379
      }
    ],
    warding_spells: [
      {
        name: "Cold Snap (512)",
        cs: 222
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Dispel (417)"
      },
      {
        name: "Tremors (909)"
      },
      {
        name: "Call Wind (912)"
      },
      {
        name: "Elemental Focus (513)"
      },
      {
        name: "Elemental Targeting (425)"
      }
    ],
    maneuvers: [
      {
        name: "Cheapshots"
      }
    ],
    special_abilities: [
      {
        name: "[[Familiar Gate (930)]]"
      },
      {
        name: "Foam"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: "250 to 261",
    ranged: nil,
    bolt: 229,
    udf: nil,
    bar_td: 205,
    cle_td: 219,
    emp_td: (217..219),
    pal_td: nil,
    ran_td: (179..193),
    sor_td: "231 to 234",
    wiz_td: 246,
    mje_td: 246,
    mne_td: 246,
    mjs_td: 219,
    mns_td: 219,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I",
      "Elemental Defense II",
      "Elemental Defense III",
      "Elemental Barrier",
      "Thurfel's Ward",
      "Prismatic Guard",
      "Mass Blur",
      "Wizard's Shield"
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
    skin: "no",
    other: "[[Glowing violet essence shard]]"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>A black forest ogre plods through the countryside, her immense arm and leg muscles rippling with each wide step.  An oversized, slavering lower jaw and two long, pointed, lower teeth give the ogre a constant toothy sneer.  The thick bones of her protruding forehead shade beady black eyes, and if there is any intelligence in those eyes, it is completely obscured by the black forest ogre's vicious malevolence.  Short, coal black hair covers the creature's body and appendages, though in many places the hair is broken by long, deep scars.</pre>"
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
