{
  schema_version: 3,
  name: "huge lightning elemental",
  noun: "",
  url: "https://gswiki.play.net/huge_lightning_elemental",
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
        name: "Charge",
        as: 460
      }
    ],
    bolt_spells: [
      {
        name: "Major Shock (910)",
        as: 469
      },
      {
        name: "Cone of Elements (518)",
        as: 469
      }
    ],
    warding_spells: [
      {
        name: "Elemental Strike (415)",
        cs: 335
      },
      {
        name: "Mind Jolt (706)",
        cs: 322
      }
    ],
    offensive_spells: [
      {
        name: "Lightning mote"
      }
    ],
    maneuvers: [
      {
        name: "Lava glob"
      },
      {
        name: "Major Elemental Wave"
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
    bolt: 331,
    udf: nil,
    bar_td: 406,
    cle_td: 431,
    emp_td: 431,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 431,
    mns_td: 431,
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
    other: "essence of air"
  },
  messaging: {
    description: [
      "The lightning elemental is a crackling mass of solidified power, definitely alien to Elanthia.  Nearly gelatinous in substance, solid bolts of lightning weave themselves into the skeletal form of some horrible beast, only to arc in an instant to a vaguely humanoid form and then back again."
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
