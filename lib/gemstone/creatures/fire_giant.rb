{
  schema_version: 3,
  name: "fire giant",
  noun: "giant",
  url: "https://gswiki.play.net/fire_giant",
  picture: "",
  level: 36,
  family: "Giant",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Element-based"
  ],
  bcs: true,
  max_hp: 508,
  speed: nil,
  height: 21,
  size: "huge",
  areas: [
    {
      name: "Volcanic Flats",
      uids: [3023001..3023017]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "War mattock",
        as: (209..262)
      }
    ],
    bolt_spells: [
      {
        name: "Major Fire (908)",
        as: 200
      },
      {
        name: "Minor Fire (906)",
        as: 200
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16N",
    immunities: [],
    melee: 103,
    ranged: (108..142),
    bolt: (106..142),
    udf: (275..342),
    bar_td: 116,
    cle_td: (129..137),
    emp_td: (124..133),
    pal_td: (105..114),
    ran_td: (106..113),
    sor_td: (125..142),
    wiz_td: nil,
    mje_td: (142..145),
    mne_td: (142..145),
    mjs_td: 152,
    mns_td: 152,
    mnm_td: (115..123),
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Resist Elements (602)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye",
    "a bruised right eye",
    "a rusted silver steel war mattock"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: "a fire giant mane",
    other: "essence of fire",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Towering high above you, the fire giant stands taller than four of the tallest giantman. Plumes of steam pour from her smoldering black skin and her flaming hair burns bright red. Eyes ablaze with fiery red hatred under its heavy brow, she looks at you as a human may look at an gnat."
    ],
    arrival: [
      "A fire giant lumbers in, engulfed in a fiery blaze!"
    ],
    flee: [
      "A fire giant lumbers {direction}, engulfed in a fiery blaze.",
      "A fire giant crawls {direction}.",
      "A fire giant seethes in pain as he limps {direction}."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    stun_break: [
      "A fire giant eyes burn with bright orange fire as {pronoun} tries to shake off the stun!"
    ],
    attacks: {
      attack: [
        "A fire giant points a flaming hand at you!",
        "A fire giant swings {weapon} at you!"
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
