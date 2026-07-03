{
  schema_version: 3,
  name: "spectre",
  noun: "",
  url: "https://gswiki.play.net/spectre",
  picture: "",
  level: 14,
  family: "Ghost",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 120,
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
        name: "Halberd",
        as: 102
      },
      {
        name: "Battle axe",
        as: 102
      }
    ],
    bolt_spells: [
      {
        name: "Minor Shock (901)",
        as: 137
      },
      {
        name: "Major Cold (907)",
        as: 137
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Call Wind (912)"
      }
    ],
    maneuvers: [],
    special_abilities: [
      {
        name: "[[Gas cloud]]"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "17",
    immunities: [],
    melee: 75,
    ranged: nil,
    bolt: 52,
    udf: nil,
    bar_td: nil,
    cle_td: 42,
    emp_td: nil,
    pal_td: nil,
    ran_td: 42,
    sor_td: 42,
    wiz_td: nil,
    mje_td: 42,
    mne_td: 42,
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
    skin: "a spectre skin",
    other: "Alchemy (common)"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>You have never seen anything quite like a spectre, so you are not really sure what to make of it or how dangerous it might be.</pre>"
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    info: {
      general: [
        "Also encountered as an unarmed (\"monk\") variant at Plains of Bone, using natural attacks instead of weapons."
      ],
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
