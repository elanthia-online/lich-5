{
  schema_version: 3,
  name: "fire rat",
  noun: "",
  url: "https://gswiki.play.net/fire_rat",
  picture: "",
  level: 16,
  family: "Rodent",
  type: "Quadruped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living",
    "Element-based"
  ],
  bcs: true,
  max_hp: 148,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Smokey Caverns",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 169
      },
      {
        name: "Claw",
        as: 169
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
    asg: "8N",
    immunities: [
      "Fire"
    ],
    melee: 102,
    ranged: nil,
    bolt: 86,
    udf: nil,
    bar_td: 42,
    cle_td: 48,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: (42..54),
    wiz_td: nil,
    mje_td: 48,
    mne_td: 42,
    mjs_td: nil,
    mns_td: 48,
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
    skin: "a fire rat tail",
    other: nil
  },
  messaging: {
    description: [
      "The fire rat is a large animal, roughly the size of a small dog. Its fur is shaggy, and rusty red in color. It has a long hairless tail, and glinting red eyes. Most dangerous are its claws which spark flame when attacking its prey."
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
