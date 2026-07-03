{
  schema_version: 3,
  name: "silverback orc",
  noun: "",
  url: "https://gswiki.play.net/silverback_orc",
  picture: "",
  level: 14,
  family: "Orc",
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
  max_hp: 170,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "High Plains",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Falchion",
        as: 163
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
    asg: "9",
    immunities: [],
    melee: (110..168),
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 48,
    cle_td: nil,
    emp_td: 21,
    pal_td: nil,
    ran_td: nil,
    sor_td: 42,
    wiz_td: nil,
    mje_td: 42,
    mne_td: (42..48),
    mjs_td: nil,
    mns_td: nil,
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
    skin: "a silverback orc knuckle",
    other: "[[Alchemy]] common"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Silver-flecked eyes match the garish silver stripe down the silverback orc's back.  It stands a hearty six feet tall, with pale white skin.  Were it not for the flecks of blood and bits of tattered flesh sticking to its skin, it mayhaps be attractive.  Or perhaps not.</pre>"
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
