{
  schema_version: 3,
  name: "red bear",
  noun: "bear",
  url: "https://gswiki.play.net/red_bear",
  picture: "",
  level: 16,
  family: "Bear",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 213,
  speed: nil,
  height: 4,
  size: "large",
  areas: [
    {
      name: "Stone Valley",
      uids: [4291001..4291025]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (160..174)
      },
      {
        name: "Bite",
        as: 174
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Charge"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (97..194),
    ranged: (97..125),
    bolt: (97..125),
    udf: 129,
    bar_td: nil,
    cle_td: (45..48),
    emp_td: (48..52),
    pal_td: (45..54),
    ran_td: (45..51),
    sor_td: 48,
    wiz_td: nil,
    mje_td: (42..54),
    mne_td: (42..54),
    mjs_td: (45..48),
    mns_td: (45..48),
    mnm_td: (45..54),
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
    skin: "a bear paw",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    attacks: {
      attack: [
        "A red bear charges at you, but seeing {pronoun} coming, you acrobatically spring over the red bear!"
      ],
      claw: [
        "A red bear claws at you!"
      ],
      bite: [
        "A red bear tries to bite you!"
      ]
    },
    stand: [
      "A red bear stands up and growls!"
    ],
    description: [
      "The red bear weighs around 600 pounds and is about seven feet long. This bear is a dark reddish-brown color and has a characteristic muscle hump over the shoulders, and has long vicious looking claws on his front paws."
    ],
    arrival: [
      "A red bear lumbers in!",
      "A red bear slowly lumbers in, growling in pain!",
      "A red bear lumbers noisily into the area drooling hungrily!"
    ],
    flee: [
      "A red bear lumbers {direction}.",
      "A red bear slowly lumbers {direction}, growling in pain.",
      "A red bear slowly backs away, {pronoun} teeth bared."
    ],
    death: [
      "The red bear collapses heavily into a heap on the ground and dies.",
      "The red bear lets out a blood-curdling roar and dies."
    ],
    decay: [
      "A red bear decays into a compost of fangs, fur and claws."
    ],
    search: [
      "A red bear snuffles the ground hungrily."
    ],
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
