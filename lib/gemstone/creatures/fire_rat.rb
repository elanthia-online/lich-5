{
  schema_version: 3,
  name: "fire rat",
  noun: "rat",
  url: "https://gswiki.play.net/fire_rat",
  picture: "",
  level: 16,
  family: "Rodent",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Element-based"
  ],
  bcs: true,
  max_hp: 148,
  speed: 12,
  height: 2,
  size: "small",
  areas: [
    {
      name: "Lysierian Hills",
      uids: [92032..92041]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (139..169)
      },
      {
        name: "Claw",
        as: 169
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
    immunities: [
      "Fire"
    ],
    melee: (72..115),
    ranged: (69..101),
    bolt: (69..101),
    udf: (78..121),
    bar_td: 42,
    cle_td: (45..54),
    emp_td: (40..51),
    pal_td: (45..48),
    ran_td: (42..48),
    sor_td: (42..54),
    wiz_td: nil,
    mje_td: (42..48),
    mne_td: (42..48),
    mjs_td: (48..54),
    mns_td: (48..54),
    mnm_td: (48..54),
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
    skin: "a fire rat tail",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    attacks: {
      bite: [
        "A fire rat tries to bite you!"
      ]
    },
    stand: [
      "A fire rat scrambles to {pronoun} feet, baring {pronoun} sharp teeth!"
    ],
    description: [
      "The fire rat is a large animal, roughly the size of a small dog. Its fur is shaggy, and rusty red in color. It has a long hairless tail, and glinting red eyes. Most dangerous are its claws which spark flame when attacking its prey."
    ],
    arrival: [
      "A fire rat scampers in!"
    ],
    flee: [
      "A fire rat scampers {direction}.",
      "A fire rat crawls {direction}.",
      "A fire rat squeaks as {pronoun} slowly backs away."
    ],
    death: [
      "The fire rat collapses to the ground, emits a final squeal, and dies.",
      "The fire rat twitches and dies.",
      "The fire rat collapses to the ground, emits a final silent squeal, and dies."
    ],
    decay: [
      "A fire rat crumbles into a pile of ash."
    ],
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
