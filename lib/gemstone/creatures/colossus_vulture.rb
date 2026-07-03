{
  schema_version: 3,
  name: "colossus vulture",
  noun: "",
  url: "https://gswiki.play.net/colossus_vulture",
  picture: "",
  level: 34,
  family: "Bird",
  type: "Avian",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 390,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Black Moor",
      rooms: []
    },
    {
      name: "Yegharren Plains",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 235
      },
      {
        name: "Claw",
        as: 245
      },
      {
        name: "Impale",
        as: 235
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Wing buffet"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (192..207),
    ranged: 165,
    bolt: 150,
    udf: 200,
    bar_td: (93..102),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: 102,
    sor_td: 113,
    wiz_td: nil,
    mje_td: 119,
    mne_td: 119,
    mjs_td: nil,
    mns_td: 107,
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
    skin: "a ruff of vulture feathers",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The colossus vulture is a large, distinctly marked bird, with a wingspan twice the height of a giantman.  Glossy black feathers and white markings on its broad wings and rounded tail give the vulture an ominous appearance, and feathers cover its legs to its feet.  A dark ruff borders the colossus vulture's bald red head and neck.  Its hooked bill and powerful talons are well suited for hunting.</pre>"
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
