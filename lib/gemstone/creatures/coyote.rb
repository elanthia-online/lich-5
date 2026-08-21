{
  schema_version: 3,
  name: "coyote",
  noun: "",
  url: "https://gswiki.play.net/coyote",
  picture: "",
  level: 5,
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
  max_hp: 60,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Foggy Valley",
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
      name: "Old Mine Road",
      rooms: []
    },
    {
      name: "Upper Trollfang",
      rooms: []
    },
    {
      name: "Vornavian Coast",
      rooms: []
    },
    {
      name: "Wehnimer's Environs",
      rooms: []
    }
  ],
  spawns: [
    { zone: 9, count: 1, uid_ranges: [[9042, 9047], [9058, 9058]] },
    { zone: 16, count: 1, uid_ranges: [[16001, 16005], [16011, 16013]] },
    { zone: 4212, count: 1, uid_ranges: [[4212101, 4212130]] },
    { zone: 4213, count: 1, uid_ranges: [[4213101, 4213130]] },
    { zone: 4214, count: 1, uid_ranges: [[4214101, 4214115]] },
    { zone: 4250, count: 1, uid_ranges: [[4250022, 4250026]] }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 95
      },
      {
        name: "Charge",
        as: 95
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
    immunities: [],
    melee: (17..54),
    ranged: nil,
    bolt: nil,
    udf: 83,
    bar_td: 15,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 15,
    wiz_td: nil,
    mje_td: 15,
    mne_td: 15,
    mjs_td: nil,
    mns_td: 15,
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
    skin: "a coyote tail",
    other: "No"
  },
  messaging: {
    description: [
      "The coyote, a quick, buff-colored creature, is a smaller cousin of the wolf. However, the coyote lacks the wolf's braver tendencies, preferring to slash and run rather than risk a frontal assault in an attempt to go for the throat. The coyote must be approached with care, as the coyote has been known to take an adventurer's hand off with one quick snap of the jaws."
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
