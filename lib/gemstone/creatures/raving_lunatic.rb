{
  schema_version: 3,
  name: "raving lunatic",
  noun: "",
  url: "https://gswiki.play.net/raving_lunatic",
  picture: "",
  level: 77,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Living",
    "Extraplanar",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Rift",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Short sword",
        as: 371
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
    asg: "8N",
    immunities: [],
    melee: nil,
    ranged: (276..346),
    bolt: (339..359),
    udf: nil,
    bar_td: 278,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 315,
    wiz_td: 330,
    mje_td: 330,
    mne_td: 330,
    mjs_td: nil,
    mns_td: 295,
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
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "[[Tiny golden seed]]"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Perhaps driven mad by the shifting world around her, the raving lunatic babbles and chatters to herself, sometimes gleefully, sometimes angrily.  A disgustingly corpulent humanoid, her rolls of pink flesh bounce and quiver as the raving lunatic staggers from area to area, not comprehending her surroundings.  Clear spittle drools from her open mouth, and her unblinking eyes dart wildly about in unfocused confusion.  She is a totally unpredictable foe.</pre>"
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
