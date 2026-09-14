{
  schema_version: 3,
  name: "fire ant",
  noun: "ant",
  url: "https://gswiki.play.net/fire_ant",
  picture: "",
  level: 1,
  family: "Ant",
  type: "Insect",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 28,
  speed: 15,
  height: 1,
  size: "small",
  areas: [
    {
      name: "unmapped",
      uids: [14010001..14010032]
    },
    {
      name: "Barefoot Hill",
      uids: [14010101..14010118]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 41
      },
      {
        name: "Charge",
        as: 51
      },
      {
        name: "Unknown",
        as: 6
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
    melee: (15..35),
    ranged: (15..25),
    bolt: (15..25),
    udf: 33,
    bar_td: 3,
    cle_td: 3,
    emp_td: 3,
    pal_td: (3..6),
    ran_td: 3,
    sor_td: 3,
    wiz_td: 3,
    mje_td: 3,
    mne_td: 3,
    mjs_td: 3,
    mns_td: 3,
    mnm_td: 3,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "a fire ant pincer",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The fire ant looks like a giant armored version of a common ordinary ant except for the faint wisps of smoke floating off its feelers. Its faceted eyes stare back at you with apparent disinterest."
    ],
    arrival: [
      "A fire ant just arrived.",
      "A fire ant crawls in, feelers twitching."
    ],
    flee: [
      "A fire ant heads {direction}."
    ],
    death: [
      "The fire ant falls to the ground and dies, its feelers twitching.",
      "The fire ant feebly twitches a feeler one last time and dies."
    ],
    decay: [
      "A fire ant decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      bite: [
        "A fire ant tries to bite you!"
      ]
    },
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
