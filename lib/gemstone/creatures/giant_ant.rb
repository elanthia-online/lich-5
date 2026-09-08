{
  schema_version: 3,
  name: "giant ant",
  noun: "ant",
  url: "https://gswiki.play.net/giant_ant",
  picture: "",
  level: 1,
  family: "Ant",
  type: "Insect",
  undead: false,
  blood: nil,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: false,
  muggable: false,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 29,
  speed: 15,
  height: 1,
  size: "small",
  areas: [
    {
      name: "Dark Caverns",
      uids: [47001..47024, 47026..47033]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (36..41)
      },
      {
        name: "Charge (attack)",
        as: 46
      },
      {
        name: "Unknown",
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
    melee: (17..47),
    ranged: (23..33),
    bolt: (23..33),
    udf: (30..42),
    bar_td: nil,
    cle_td: (3..6),
    emp_td: (3..6),
    pal_td: (0..6),
    ran_td: 3,
    sor_td: (3..6),
    wiz_td: nil,
    mje_td: 3,
    mne_td: 3,
    mjs_td: (3..6),
    mns_td: (3..6),
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
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "an ant pincer",
    other: "ant larva",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The giant ant looks like a giant armored version of a common ordinary ant. Its faceted eyes stare out into air with constant disinterest."
    ],
    arrival: [
      "A giant ant just arrived."
    ],
    flee: [
      "A giant ant heads {direction}."
    ],
    death: [
      "The giant ant falls to the ground and dies, its feelers twitching.",
      "The giant ant feebly twitches a feeler one last time and dies."
    ],
    decay: [
      "A giant ant decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      bite: [
        "A giant ant tries to bite you!"
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
