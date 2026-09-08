{
  schema_version: 3,
  name: "bone golem",
  noun: "golem",
  url: "https://gswiki.play.net/bone_golem",
  picture: "",
  level: 8,
  family: "Golem",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: false,
  sympathy: false,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 90,
  speed: 8,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Plains of Bone",
      uids: [14011001..14011022]
    },
    {
      name: "The Citadel",
      uids: [2102001..2102006, 2102059..2102069]
    },
    {
      name: "Upper Trollfang",
      uids: [14070..14079]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ensnare",
        as: 97
      },
      {
        name: "Pound",
        as: 107
      },
      {
        name: "Skeletal fist",
        as: 97
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tail sweep"
      },
      {
        name: "Tail Swipe"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (2..93),
    ranged: (13..16),
    bolt: (13..16),
    udf: (43..146),
    bar_td: (24..27),
    cle_td: 24,
    emp_td: 24,
    pal_td: (21..24),
    ran_td: 24,
    sor_td: 24,
    wiz_td: 24,
    mje_td: 24,
    mne_td: 24,
    mjs_td: 24,
    mns_td: 24,
    mnm_td: 24,
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
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a golem bone",
    other: "crystal core",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Dried bones send sickening clacking sounds throughout the area at the barest movement of a bone golem. Its large skull capped with twin horns formed of sharply spiraled bone begins a long spine ending in a sharp tail that whips back and forth in a vicious swipe. Even longer than the snout of the bone golem are its sickly jointed claws which have been filed at the ends into terrifying weapons. Contrary to the empty feeling of its bones, it moves with the blocky movement of an enormous, fleshed creature."
    ],
    arrival: [],
    flee: [
      "A bone golem pounds {direction}, shuffling slowly but surely."
    ],
    death: [],
    decay: [
      "A bone golem's remains wither into dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A bone golem pounds at you with {pronoun} skeletal fist!",
        "A bone golem tries to ensnare {target} in {pronoun} bony arms!",
        "A bone golem tries to ensnare you in {pronoun} bony arms!",
        "A bone golem swings {pronoun} segmented tail of bestial vertebrae at {target}!"
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
