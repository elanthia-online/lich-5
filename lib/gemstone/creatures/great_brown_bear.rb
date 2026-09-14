{
  schema_version: 3,
  name: "great brown bear",
  noun: "bear",
  url: "https://gswiki.play.net/great_brown_bear",
  picture: "",
  level: 14,
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
  max_hp: 190,
  speed: 14,
  height: 4,
  size: "large",
  areas: [
    {
      name: "Upper Trollfang",
      uids: [14001..14023, 17020..17025, 17101..17118, 17127..17127]
    },
    {
      name: "unmapped",
      uids: [17119..17126]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (189..191)
      },
      {
        name: "Bite",
        as: (182..184)
      },
      {
        name: "Charge (attack)",
        as: 194
      },
      {
        name: "Charge",
        as: 179
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
    melee: (91..145),
    ranged: (64..97),
    bolt: (64..97),
    udf: (106..155),
    bar_td: nil,
    cle_td: (39..45),
    emp_td: (42..50),
    pal_td: (39..42),
    ran_td: (39..48),
    sor_td: (39..48),
    wiz_td: nil,
    mje_td: (42..48),
    mne_td: (42..48),
    mjs_td: (39..57),
    mns_td: (39..57),
    mnm_td: 42,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: [
      "Hides when attacked"
    ]
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
    skin: "a brown bear skin",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The great brown bear weighs around 500 pounds and is about eight feet long. This bear is dark brown in color and has a characteristic muscle hump over the shoulders and longer claws on her front paws than on her rear paws."
    ],
    arrival: [
      "A great brown bear lumbers in!",
      "A great brown bear slowly lumbers in, growling in pain!",
      "A great brown bear lumbers noisily into the area drooling hungrily!"
    ],
    flee: [
      "A great brown bear slowly lumbers {direction}, growling in pain.",
      "A great brown bear lumbers {direction}.",
      "A great brown bear slowly backs away, {pronoun} teeth bared."
    ],
    death: [
      "The great brown bear collapses heavily into a heap on the ground and dies.",
      "The great brown bear lets out a blood-curdling roar and dies."
    ],
    decay: [
      "A great brown bear decays into a compost of fangs, fur and claws.",
      "A small, green cloud of smelly gas rises from the body of a kobold as he decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A great brown bear charges at you!",
        "A great brown bear charges at you, but seeing {pronoun} coming, you acrobatically spring over the great brown bear!"
      ],
      bite: [
        "A great brown bear tries to bite you!"
      ],
      claw: [
        "A great brown bear claws at you!"
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
