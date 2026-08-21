{
  schema_version: 3,
  name: "scaly burgee",
  noun: "",
  url: "https://gswiki.play.net/scaly_burgee",
  picture: "",
  level: 29,
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
  max_hp: 340,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Greymist Wood",
      rooms: []
    },
    {
      name: "Teorainn Dale",
      rooms: []
    }
  ],
  spawns: [
    { zone: 3022, count: 1, uid_ranges: [[3022018, 3022034]] },
    { zone: 13024, count: 2, uid_ranges: [[13024030, 13024047], [13024051, 13024064]] }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge (attack)",
        as: 250
      },
      {
        name: "Claw",
        as: 247
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Spit"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (185..263),
    ranged: 140,
    bolt: 151,
    udf: 289,
    bar_td: 87,
    cle_td: nil,
    emp_td: 93,
    pal_td: nil,
    ran_td: 87,
    sor_td: 91,
    wiz_td: nil,
    mje_td: (95..98),
    mne_td: 95,
    mjs_td: nil,
    mns_td: 87,
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
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a scaly burgee shell",
    other: nil
  },
  messaging: {
    description: [
      "The dark, beady eyes of the scaly burgee gleam with feral menace beneath two jutting ridges. Flexible diamond-shaped scales cover its carapace and its small, triangular head. Thinly coated around its surprisingly wide mouth is a greyish substance."
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
