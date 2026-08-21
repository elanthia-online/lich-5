{
  schema_version: 3,
  name: "kobold",
  noun: "",
  url: "https://gswiki.play.net/kobold",
  picture: "",
  level: 1,
  family: "Kobold",
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
  max_hp: 40,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Briar Thicket",
      rooms: []
    },
    {
      name: "Icemule Environs",
      rooms: []
    },
    {
      name: "Kobold Village",
      rooms: []
    },
    {
      name: "Marshtown",
      rooms: []
    },
    {
      name: "North Beach",
      rooms: []
    },
    {
      name: "Solhaven Environs",
      rooms: []
    },
    {
      name: "Wehnimer's Environs",
      rooms: []
    }
  ],
  spawns: [
    { zone: 9, count: 1, uid_ranges: [[9028, 9041]] },
    { zone: 20, count: 1, uid_ranges: [[20002, 20018]] },
    { zone: 372, count: 4, uid_ranges: [[372005, 372014], [372020, 372026]] },
    { zone: 373, count: 3, uid_ranges: [[373005, 373016], [373020, 373021]] },
    { zone: 401, count: 1, uid_ranges: [[401002, 401015], [401101, 401102], [401201, 401209]] },
    { zone: 4128, count: 1, uid_ranges: [[4128005, 4128008], [4128012, 4128016]] },
    { zone: 4212, count: 1, uid_ranges: [[4212101, 4212130]] },
    { zone: 4213, count: 1, uid_ranges: [[4213101, 4213130]] },
    { zone: 14013, count: 2, uid_ranges: [[14013001, 14013018]] }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Short sword",
        as: 36
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
    asg: nil,
    immunities: [],
    melee: 18,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 3,
    cle_td: nil,
    emp_td: 3,
    pal_td: 3,
    ran_td: 3,
    sor_td: 3,
    wiz_td: nil,
    mje_td: 3,
    mne_td: 3,
    mjs_td: 3,
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
    skin: "kobold skin",
    other: nil
  },
  messaging: {
    description: [
      "Smaller than a dwarf and even many halflings, she has ruddy skin and a hairless pate topped with small horns. Long-limbed for her size, the kobold eschews any display of brute strength and relies on what agility she pretends to have. The kobold stares back at you with beady little black eyes, sizing you up as a foe.\n\nAppraisal:\nThe kobold is small in size, about three feet high in his current state, appears to be of weak constitution, is in a forward stance, and is in relatively good shape."
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
