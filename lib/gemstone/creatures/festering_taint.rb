{
  schema_version: 3,
  name: "festering taint",
  noun: "",
  url: "https://gswiki.play.net/festering_taint",
  picture: "",
  level: 86,
  family: "Humanoid",
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
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Old Ta'Faendryl",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (408..420)
      }
    ],
    bolt_spells: [
      {
        name: "Fire Spirit (111)",
        as: 369
      }
    ],
    warding_spells: [
      {
        name: "Curse (715)",
        cs: 379
      },
      {
        name: "Dark Catalyst (719)",
        cs: 379
      },
      {
        name: "Disease (716)",
        cs: 379
      },
      {
        name: "Disintegrate (705)",
        cs: 379
      },
      {
        name: "Mind Jolt (706)",
        cs: 379
      },
      {
        name: "Unbalance (110)",
        cs: 366
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Grasp of the Grave (709)"
      }
    ],
    maneuvers: [],
    special_abilities: [
      {
        name: "Putrid Air"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: 403,
    ranged: 291,
    bolt: nil,
    udf: nil,
    bar_td: 327,
    cle_td: nil,
    emp_td: nil,
    pal_td: 296,
    ran_td: nil,
    sor_td: (340..380),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 378,
    mjs_td: nil,
    mns_td: 339,
    mnm_td: nil,
    defensive_spells: [
      "Lesser Shroud (120)",
      "Spirit Defense (103)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)",
      "Wall of Force (140)"
    ],
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
      "<pre{{log2|margin-right=26em}}>The festering taint is a putrescent collection of rotting flesh and disease.  The gender of the taint is impossible to make out due to the scabs and boils which cover its skin, oozing out disgustingly.  Black and yellow rotting teeth are displayed in a mouth that is unnaturally wide underneath two black eyes that stare out with a frightening spark of intelligence.  No nose or ears are visible on the festering taint, but it has a mop of greasy, filthy black hair that sprouts from the top of its head.</pre>"
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
