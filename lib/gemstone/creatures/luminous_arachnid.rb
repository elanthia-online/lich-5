{
  schema_version: 3,
  name: "luminous arachnid",
  noun: "",
  url: "https://gswiki.play.net/luminous_arachnid",
  picture: "",
  level: 15,
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
  max_hp: 140,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Thurfel's Keep",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 150
      },
      {
        name: "Ensnare",
        as: 152
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
    melee: (65..110),
    ranged: nil,
    bolt: nil,
    udf: 115,
    bar_td: 45,
    cle_td: 45,
    emp_td: 45,
    pal_td: 45,
    ran_td: nil,
    sor_td: 45,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 45,
    mjs_td: nil,
    mns_td: 45,
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
    other: nil
  },
  messaging: {
    description: [
      "Dotting the pale-skinned arachnid are numerous tiny luminescent diamond-shaped markings. The markings glow with a bluish-green tint."
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
