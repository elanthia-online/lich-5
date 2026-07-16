{
  schema_version: 3,
  name: "mammoth arachnid",
  noun: "",
  url: "https://gswiki.play.net/mammoth_arachnid",
  picture: "",
  level: 30,
  family: "Arachnid",
  type: "Arachnid",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 350,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Foggy Valley",
      rooms: []
    },
    {
      name: "Sorcerer's Isle",
      rooms: []
    },
    {
      name: "Spider Temple",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 212
      },
      {
        name: "Ensnare",
        as: 222
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Web"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: 124,
    ranged: 120,
    bolt: nil,
    udf: nil,
    bar_td: (90..96),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: (89..95),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 100,
    mjs_td: nil,
    mns_td: 91,
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
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a mammoth arachnid mandible",
    other: nil
  },
  messaging: {
    description: [
      "The mammoth arachnid towers over its prey, fangs dripping poison mixed with fresh blood from its last kill shortly ago. Its entire body is draped with long, coal black hair, with the exception of a small patch on the very rear tip of its bulbous abdomen. This contains the spinnerets it uses to effectively web its prey before injecting the victim with a caustic poison, resulting in slow disintegration from the inside. The arachnid's eight crimson eyes dart about, making certain no prey, no matter how small, escapes."
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
