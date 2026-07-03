{
  schema_version: 3,
  name: "huge lava elemental",
  noun: "",
  url: "https://gswiki.play.net/huge_lava_elemental",
  picture: "",
  level: 100,
  family: "Elemental",
  type: "Elemental",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Extraplanar",
    "Magical"
  ],
  bcs: true,
  max_hp: nil,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Elemental Confluence",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound (double attack)",
        as: 450
      }
    ],
    bolt_spells: [
      {
        name: "Major Fire (908)",
        as: 469
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Lava glob"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "10",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: 335,
    udf: nil,
    bar_td: 406,
    cle_td: 428,
    emp_td: 428,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 428,
    mns_td: 428,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Barrier",
      "Elemental Bias",
      "Elemental Defense I",
      "Elemental Defense II",
      "Elemental Defense III",
      "Elemental Targeting"
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
    boxes: nil,
    skin: nil,
    other: "essence of fire"
  },
  messaging: {
    description: [
      "The lava elemental is a bubbling mound of lava, across which an occasional warped face appears before dissolving away. Various appendages form and melt away constantly, as the alien creature goes about its business."
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
