{
  schema_version: 3,
  name: "krag yeti",
  noun: "",
  url: "https://gswiki.play.net/krag_yeti",
  picture: "",
  level: 70,
  family: "Yeti",
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
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Wehntoph",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Hairy hand",
        as: 364
      },
      {
        name: "Ensnare",
        as: (383..386)
      },
      {
        name: "Closed fist",
        as: 388
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Arm Entrapment/Bear Hug"
      },
      {
        name: "[[Ground slap]]"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: 287,
    ranged: 288,
    bolt: (283..308),
    udf: nil,
    bar_td: (210..262),
    cle_td: (198..219),
    emp_td: (260..266),
    pal_td: (235..242),
    ran_td: 230,
    sor_td: 283,
    wiz_td: nil,
    mje_td: (293..302),
    mne_td: 297,
    mjs_td: nil,
    mns_td: 266,
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
      "A towering mound of fur that belies her swift blinding speed, the krag yeti is at home either in the sub-zero wasteland or on rocky mountain tops.  The krag yeti's white fur allows an almost perfect blend with the natural surroundings, enabling the creature to move with uncommon stealth.  Legendary strength and fury make her a formidable opponent for any who would cross her."
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
