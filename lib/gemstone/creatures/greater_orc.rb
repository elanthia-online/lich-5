{
  schema_version: 3,
  name: "greater orc",
  noun: "",
  url: "https://gswiki.play.net/greater_orc",
  picture: "",
  level: 8,
  family: "Orc",
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
  max_hp: 110,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Cairnfang Forest",
      rooms: []
    },
    {
      name: "Foggy Valley",
      rooms: []
    },
    {
      name: "Marshtown",
      rooms: []
    },
    {
      name: "The Citadel",
      rooms: []
    },
    {
      name: "Upper Trollfang",
      rooms: []
    },
    {
      name: "Zeltoph",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Spear",
        as: 126
      },
      {
        name: "War mattock",
        as: 113
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "varies",
    immunities: [],
    melee: (62..78),
    ranged: 71,
    bolt: 71,
    udf: nil,
    bar_td: 24,
    cle_td: 24,
    emp_td: 24,
    pal_td: nil,
    ran_td: nil,
    sor_td: 24,
    wiz_td: nil,
    mje_td: 24,
    mne_td: 24,
    mjs_td: 24,
    mns_td: 24,
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
    skin: "an orc scalp",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Taller than a human and of substantially heavier build, the greater orc is a solid mass of bone and gristle.  Red-rimmed eyes glare angrily out from under a thick bony forehead.  Irregular clumps of rank hair cover its body and head.  Its arms resemble thick and twisted tree trunks, ending in ragged claws crusted with dried gore.</pre>"
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
