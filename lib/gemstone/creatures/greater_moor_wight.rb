{
  schema_version: 3,
  name: "greater moor wight",
  noun: "wight",
  url: "https://gswiki.play.net/greater_moor_wight",
  picture: "",
  level: 39,
  family: "Wight",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 238,
  speed: 8,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Miasmal Forest",
      uids: [5003039..5003050, 5004035..5004044, 5004049..5004053]
    },
    {
      name: "unmapped",
      uids: [5004045..5004048, 5004054..5004054]
    },
    {
      name: "Yegharren Plains",
      uids: [13036201..13036217, 13036401..13036414, 13036501..13036514]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Broadsword"
      },
      {
        name: "Handaxe",
        as: (226..252)
      },
      {
        name: "Rusty steel flyssa",
        as: 246
      },
      {
        name: "Wickedly curved scimitar",
        as: 226
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Cold Snap (512)",
        cs: 203
      },
      {
        name: "Claw Curse",
        cs: 189
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Dispel (417)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (150..315),
    ranged: (163..250),
    bolt: (163..250),
    udf: (241..372),
    bar_td: 133,
    cle_td: (152..164),
    emp_td: (155..164),
    pal_td: (133..142),
    ran_td: (132..142),
    sor_td: (162..171),
    wiz_td: nil,
    mje_td: (158..167),
    mne_td: (158..167),
    mjs_td: (145..155),
    mns_td: (145..155),
    mnm_td: (119..128),
    defensive_spells: [
      "Haste (506)",
      "Mass Blur (911)",
      "Prismatic Guard (905)",
      "Spirit Defense (103)",
      "Spirit Warding I (101)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a rusty steel flyssa",
    "a wickedly curved scimitar",
    "a large dual-bit handaxe",
    "some rancid brown brigandine"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a wight mane",
    other: "Glowing violet essence dust",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Once beautiful beyond comprehension, the moor wight before you is now as disgusting as it was once charming. The wight has a slender, decaying body hidden by tattered and fading robes. Plainly written across the moor wight's face is an expression of eternal anguish and pain, silently speaking of the horrific events which unfolded during its life to bring it to this sad state."
    ],
    arrival: [],
    flee: [
      "A greater moor wight wails madly as it limps {direction}.",
      "A greater moor wight moves off, heading {direction}."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [
      "A greater moor wight gestures arcanely."
    ],
    attacks: {
      attack: [
        "A greater moor wight swings {weapon} at you!",
        "A greater moor wight swings a wickedly curved scimitar at {target}!",
        "A greater moor wight swings a large dual-bit handaxe at {target}!"
      ],
      cast: [
        "A greater moor wight points a clawed finger at {target}!"
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
