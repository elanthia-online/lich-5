{
  schema_version: 3,
  name: "thrak",
  noun: "",
  url: "https://gswiki.play.net/thrak",
  picture: "",
  level: 8,
  family: "Reptilian",
  type: "Quadruped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 80,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Old Mine Road",
      rooms: []
    },
    {
      name: "Vornavian Coast",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 110
      },
      {
        name: "Charge",
        as: 120
      },
      {
        name: "Claw",
        as: 110
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
    asg: "11N",
    immunities: [],
    melee: 68,
    ranged: 57,
    bolt: 57,
    udf: nil,
    bar_td: 24,
    cle_td: 24,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 24,
    wiz_td: 24,
    mje_td: 24,
    mne_td: 24,
    mjs_td: 24,
    mns_td: 24,
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
    skin: "a thrak hide",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>This odd creature looks unnatural, as though some wizard had been meddling with its shape.  It looks like a large, 4-foot-long lizard, with an uncomfortably large variety of teeth in its long snout.</pre>"
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
