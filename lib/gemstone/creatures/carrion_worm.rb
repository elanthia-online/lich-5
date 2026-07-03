{
  schema_version: 3,
  name: "carrion worm",
  noun: "",
  url: "https://gswiki.play.net/carrion_worm",
  picture: "",
  level: 1,
  family: "Worm",
  type: "Worm",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 28,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Coastal Cliffs",
      rooms: []
    },
    {
      name: "Icemule Environs",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge",
        as: 39
      },
      {
        name: "Bite",
        as: 29
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
    asg: "1N",
    immunities: [],
    melee: (27..68),
    ranged: nil,
    bolt: 25,
    udf: "40 varies",
    bar_td: 3,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 3,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 3,
    mjs_td: 3,
    mns_td: 3,
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
    skin: "worm skin",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The carrion worm eagerly consumes anything dead and anything living that doesn't put up too much of a fight.  Its long, slimy body tapers to a point at the tail end.  At the business end, several hundred waving cilia force food into the worm's maw where the food is crushed by rows of short, sharp teeth.  The carrion worm hunts blindly, using its keen sense of smell and hearing to locate its prey.</pre>"
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
