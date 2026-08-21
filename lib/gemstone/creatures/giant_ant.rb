{
  schema_version: 3,
  name: "giant ant",
  noun: "",
  url: "https://gswiki.play.net/giant_ant",
  picture: "",
  level: 1,
  family: "Ant",
  type: "Insect",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 29,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Wehnimer's Landing",
      rooms: []
    }
  ],
  spawns: [
    { zone: 47, count: 2, uid_ranges: [[47001, 47024], [47026, 47033]] }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 36
      },
      {
        name: "Charge (attack)",
        as: 46
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
    asg: "5N",
    immunities: [],
    melee: (25..47),
    ranged: (23..33),
    bolt: (23..33),
    udf: 42,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 3,
    wiz_td: nil,
    mje_td: 3,
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
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "an ant pincer",
    other: "ant larva"
  },
  messaging: {
    description: [
      "The giant ant looks like a giant armored version of a common ordinary ant. Its faceted eyes stare out into air with constant disinterest."
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
