{
  schema_version: 3,
  name: "fire mage",
  noun: "",
  url: "https://gswiki.play.net/fire_mage",
  picture: "",
  level: 71,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Living",
    "Element-based",
    "Boss"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Eye of V'Tull",
      rooms: []
    },
    {
      name: "Glaes Caverns",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist"
      }
    ],
    bolt_spells: [
      {
        name: "Major Fire (908)",
        as: 311
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Earthen Fury"
      },
      {
        name: "Firestorm"
      },
      {
        name: "Sleep"
      },
      {
        name: "Tremors"
      },
      {
        name: "Weapon Fire"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [],
    melee: nil,
    ranged: (285..295),
    bolt: nil,
    udf: nil,
    bar_td: (251..285),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 316,
    wiz_td: nil,
    mje_td: 345,
    mne_td: 333,
    mjs_td: nil,
    mns_td: 294,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Barrier",
      "Elemental Defense I",
      "Elemental Defense II",
      "Elemental Defense III",
      "Elemental Focus",
      "Elemental Targeting",
      "Mass Blur",
      "Prismatic Guard",
      "Thurfel's Ward"
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
      "<pre{{log2|margin-right=26em}}>The fire mage isn't tall, standing no more than five feet, but her harrowing image is more than intimidating.  Blackened skin of her face is framed with a wild mane of silvery hair, which lifts in the smoke and flames rising from the mage's robes like writhing serpents.  Twin pits of fire glare out of the apparition's eye sockets, constantly sweeping her surroundings with maleficent intent.</pre>"
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
