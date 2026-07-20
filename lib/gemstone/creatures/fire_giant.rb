{
  schema_version: 3,
  name: "fire giant",
  noun: "",
  url: "https://gswiki.play.net/fire_giant",
  picture: "",
  level: 36,
  family: "Giant",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living",
    "Element-based"
  ],
  bcs: true,
  max_hp: 500,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Greymist Wood",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "War mattock",
        as: 262
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
    ranged: 127,
    bolt: 106,
    udf: nil,
    bar_td: 116,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 142,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
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
  treasure: {
    coins: nil,
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: "a fire giant mane",
    other: nil
  },
  messaging: {
    description: [
      "Towering high above you, the fire giant stands taller than four of the tallest giantman. Plumes of steam pour from her smoldering black skin and her flaming hair burns bright red. Eyes ablaze with fiery red hatred under its heavy brow, she looks at you as a human may look at an gnat."
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
