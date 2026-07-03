{
  schema_version: 3,
  name: "dreadnought raptor",
  noun: "",
  url: "https://gswiki.play.net/dreadnought_raptor",
  picture: "",
  level: 43,
  family: "Bird",
  type: "Avian",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 260,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Gyldemar Green",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Impale",
        as: "(spear) 275"
      },
      {
        name: "Bite",
        as: "(impale) 275"
      },
      {
        name: "Claw",
        as: 275
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Buffet"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: 197,
    ranged: nil,
    bolt: nil,
    udf: 240,
    bar_td: (122..131),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 153,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 144,
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
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "raptor feathers",
    other: nil
  },
  messaging: {
    description: [
      "The dreadnought raptor is a large, distinctly marked bird, with a wingspan twice the height of a giantman. Glossy black feathers and white markings on its broad wings and rounded tail give the raptor an ominous appearance, and feathers cover its legs to its feet. A dark ruff borders the dreadnought raptor's bald red head and neck. Its hooked bill and powerful talons are well suited for hunting."
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
