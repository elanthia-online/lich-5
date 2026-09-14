{
  schema_version: 3,
  name: "puma",
  noun: "puma",
  url: "https://gswiki.play.net/puma",
  picture: "",
  level: 15,
  family: "Feline",
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
    "Living"
  ],
  bcs: true,
  max_hp: 140,
  speed: nil,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Vornavian Coast",
      uids: [4202182..4202199]
    },
    {
      name: "Lysierian Hills",
      uids: [92079..92081, 92095..92099, 93045..93056]
    },
    {
      name: "Noralgar Forest",
      uids: [4286004..4286014, 4286019..4286023, 4286046..4286067]
    },
    {
      name: "Northern Slopes of Wehntoph",
      uids: [4302013..4302035]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (134..171)
      },
      {
        name: "Claw",
        as: (160..163)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Leap"
      }
    ],
    special_abilities: [
      {
        name: "Pounce"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [],
    melee: (108..151),
    ranged: (81..105),
    bolt: (81..105),
    udf: (101..146),
    bar_td: 51,
    cle_td: (42..51),
    emp_td: (45..53),
    pal_td: (39..48),
    ran_td: (45..51),
    sor_td: (39..51),
    wiz_td: nil,
    mje_td: (39..45),
    mne_td: (39..45),
    mjs_td: (39..48),
    mns_td: (39..48),
    mnm_td: (42..51),
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
    skin: "a puma hide",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The puma is a muscular and athletic animal. Covered with a uniform coat of greyish-brown fur, her long, lithe body is equipped with powerful legs, displaying a proportionately greater difference in the length of the forelegs compared to the extenuated hind limbs. The feline's head is topped with rounded ears, and a very long, balancing tail completes the puma's physique."
    ],
    arrival: [
      "A puma scampers in!",
      "A puma pounces to the ground in front of you!"
    ],
    flee: [
      "A puma scampers {direction}.",
      "A puma scampers {direction}, mewling in pain."
    ],
    death: [
      "The puma lets out a final caterwaul and dies.",
      "The puma crumples to the ground and dies."
    ],
    decay: [
      "A puma decays into a compost of fangs, fur and claws."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      claw: [
        "A puma claws at you!"
      ],
      bite: [
        "A puma tries to bite you!"
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
