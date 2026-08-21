{
  schema_version: 3,
  name: "wolverine",
  noun: "",
  url: "https://gswiki.play.net/wolverine",
  picture: "",
  level: 24,
  family: "Mustelid",
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
  max_hp: 210,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Foggy Valley",
      rooms: []
    },
    {
      name: "Northern Mountains",
      rooms: []
    }
  ],
  spawns: [
    { zone: 4214, count: 1, uid_ranges: [[4214303, 4214323]] },
    { zone: 4563, count: 1, uid_ranges: [[4563004, 4563021]] }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 234
      },
      {
        name: "Claw"
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
    asg: "11N",
    immunities: [],
    melee: (187..211),
    ranged: 205,
    bolt: 205,
    udf: 225,
    bar_td: 72,
    cle_td: nil,
    emp_td: nil,
    pal_td: 72,
    ran_td: nil,
    sor_td: 79,
    wiz_td: nil,
    mje_td: 81,
    mne_td: 82,
    mjs_td: nil,
    mns_td: 76,
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
    skin: "a wolverine pelt",
    other: nil
  },
  messaging: {
    description: [
      "Possessed with a ferocious nature far out of proportion to its size, this wolverine appears to be an extremely vicious opponent. Swift and agile, with claws and teeth backed by muscles like coiled springs, the wolverine will take on and defeat foes three times its size. Even stout boiled leather is oft times no match for its powerful claws and ferocious bite. There is commonly a touch of foam about its mouth, which may indicate some type of virulent disease."
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
