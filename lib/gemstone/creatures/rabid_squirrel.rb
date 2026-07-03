{
  schema_version: 3,
  name: "rabid squirrel",
  noun: "",
  url: "https://gswiki.play.net/rabid_squirrel",
  picture: "",
  level: 2,
  family: "Rodent",
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
  max_hp: 36,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Icemule Environs",
      rooms: []
    },
    {
      name: "Kobold Village",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Nip (attack)"
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
    asg: "1N",
    immunities: [],
    melee: (14..29),
    ranged: nil,
    bolt: 27,
    udf: 48,
    bar_td: nil,
    cle_td: 6,
    emp_td: 6,
    pal_td: 6,
    ran_td: 6,
    sor_td: 6,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 6,
    mjs_td: 6,
    mns_td: 6,
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
    gems: nil,
    boxes: nil,
    skin: "a squirrel tail",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>A rabid squirrel is twice the size of your average squirrel.  Its beady little eyes are blood-shot and watery and its mangy coat is a lusterless grey.  The evil little creature slavers constantly and moves with terrifying speed.</pre>"
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
