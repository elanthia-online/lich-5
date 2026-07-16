{
  schema_version: 3,
  name: "water hound",
  noun: "",
  url: "https://gswiki.play.net/water_hound",
  picture: "",
  level: 24,
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
  max_hp: 210,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Stormpeak",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 192
      },
      {
        name: "Claw",
        as: 202
      }
    ],
    bolt_spells: [
      {
        name: "Minor Water (903)",
        as: 171
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: 74,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 79,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 82,
    mjs_td: 76,
    mns_td: 76,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: [
      "Shakes off stuns"
    ]
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
    skin: "water hound pelt",
    other: "Essence of water"
  },
  messaging: {
    description: [
      "You have never seen anything quite like a water hound, so you are not really sure what to make of it or how dangerous it might be.\n\n;Assess\nThe water hound is medium in size and about three feet high in its current state."
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
