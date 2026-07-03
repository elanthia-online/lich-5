{
  schema_version: 3,
  name: "sand devil",
  noun: "",
  url: "https://gswiki.play.net/sand_devil",
  picture: "",
  level: 48,
  family: "Reptilian",
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
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Fhorian Village",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw (attack)",
        as: 273
      },
      {
        name: "Pound (attack)",
        as: 303
      }
    ],
    bolt_spells: [
      {
        name: "Minor Shock (901)",
        as: 283
      },
      {
        name: "Minor Water (903)",
        as: 273
      },
      {
        name: "Minor Fire (906)",
        as: 263
      },
      {
        name: "Minor Cold (1709)",
        as: 263
      }
    ],
    warding_spells: [
      {
        name: "Web (118)"
      }
    ],
    offensive_spells: [
      {
        name: "Sandstorm (914)"
      },
      {
        name: "Energy Maelstrom (710)"
      },
      {
        name: "Tangleweed (610)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "2N",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: (168..171),
    cle_td: nil,
    emp_td: (183..185),
    pal_td: nil,
    ran_td: nil,
    sor_td: (196..197),
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: 202,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Warding II (107)",
      "Lesser Shroud (120)",
      "Wall of Force (140)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Elemental Targeting (425)",
      "Elemental Barrier (430)",
      "Mobility (618)"
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
    skin: "No",
    other: "glowing violet essence dust"
  },
  messaging: {
    description: [
      "Mutiple attack abilities, including a command of many offensive spells, make the sand devil a most dangerous adversary. Its name comes from the appearance of its leathery, yellowish, reptilian head crowned with two long, upright, black horns. The sand devil swirls in and out of areas, constantly rotating to keep the wind and dust whipping around it. This allows its sharp claws to remain hidden, emerging suddenly from the sandstorm to slash at surprised foes."
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
