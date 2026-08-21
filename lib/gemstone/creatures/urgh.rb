{
  schema_version: 3,
  name: "urgh",
  noun: "",
  url: "https://gswiki.play.net/urgh",
  picture: "",
  level: 4,
  family: "Suine",
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
  max_hp: 51,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Cairnfang Forest",
      rooms: []
    },
    {
      name: "Dead Plateau",
      rooms: []
    },
    {
      name: "Marshtown",
      rooms: []
    },
    {
      name: "Vornavian Coast",
      rooms: []
    }
  ],
  spawns: [
    { zone: 2131, count: 1, uid_ranges: [[2131013, 2131024]] },
    { zone: 4212, count: 1, uid_ranges: [[4212101, 4212130]] },
    { zone: 4213, count: 1, uid_ranges: [[4213101, 4213130]] },
    { zone: 4600, count: 1, uid_ranges: [[4600001, 4600009]] },
    { zone: 13001, count: 2, uid_ranges: [[13001001, 13001038]] }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Impale",
        as: 84
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
    asg: "12N",
    immunities: [],
    melee: (21..51),
    ranged: 19,
    bolt: 19,
    udf: 72,
    bar_td: 12,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 12,
    wiz_td: nil,
    mje_td: 12,
    mne_td: 12,
    mjs_td: nil,
    mns_td: 12,
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
    skin: "urgh hide",
    other: nil
  },
  messaging: {
    description: [
      "The herbivorous urgh resembles, if anything, an overgrown, hairy pig. He stands on four feet and has a dark brown coat and curled, hairless tail. Instead of the usual upper and lower jaw in the front of his head, though, the urgh has an extremely long upper lip, which he can extend a good two feet to drag vegetation back into his mouth. Under the mouth reside two long, sharp tusks, used for digging up peat and other grasses upon which the urgh feeds, and for defense."
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
