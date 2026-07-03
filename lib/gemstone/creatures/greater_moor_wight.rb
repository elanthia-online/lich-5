{
  schema_version: 3,
  name: "greater moor wight",
  noun: "",
  url: "https://gswiki.play.net/greater_moor_wight",
  picture: "",
  level: 39,
  family: "Wight",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Black Moor",
      rooms: []
    },
    {
      name: "Miasmal Forest",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Broadsword",
        as: (252..267)
      },
      {
        name: "Handaxe",
        as: 252
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Cold Snap (512)",
        cs: 203
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
    melee: (170..195),
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 133,
    cle_td: (152..155),
    emp_td: 146,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 160,
    mjs_td: nil,
    mns_td: 145,
    mnm_td: nil,
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
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a wight mane",
    other: "[[Glowing violet essence dust]]"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Once beautiful beyond comprehension, the moor wight before you is now as disgusting as it was once charming.  The wight has a slender, decaying body hidden by tattered and fading robes.  Plainly written across the moor wight's face is an expression of eternal anguish and pain, silently speaking of the horrific events which unfolded during its life to bring it to this sad state.</pre>"
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
