{
  schema_version: 3,
  name: "rabid guard dog",
  noun: "",
  url: "https://gswiki.play.net/rabid_guard_dog",
  picture: "",
  level: 10,
  family: "Canine",
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
  max_hp: 100,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Thurfel's Keep",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (118..128)
      },
      {
        name: "Charge (attack)",
        as: (106..128)
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
    asg: "6N",
    immunities: [],
    melee: 77,
    ranged: nil,
    bolt: 37,
    udf: (56..86),
    bar_td: 30,
    cle_td: 30,
    emp_td: 5,
    pal_td: nil,
    ran_td: nil,
    sor_td: 30,
    wiz_td: nil,
    mje_td: 30,
    mne_td: 30,
    mjs_td: nil,
    mns_td: 30,
    mnm_td: 30,
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
    skin: "a rotted canine",
    other: nil
  },
  messaging: {
    description: [
      "Smaller than most dogs, the short hair of this beast is mangy and unkempt. Its beady eyes gaze alertly in all directions, while his stubby tail flicks back and forth with rhythmic precision."
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
