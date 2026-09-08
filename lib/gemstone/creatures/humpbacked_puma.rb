{
  schema_version: 3,
  name: "humpbacked puma",
  noun: "puma",
  url: "https://gswiki.play.net/humpbacked_puma",
  picture: "",
  level: 15,
  family: "Feline",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
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
  max_hp: 140,
  speed: 12,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Liath Bheinn and Aillidh Brae",
      uids: [4250062..4250067]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite (attack)",
        as: 168
      },
      {
        name: "Claw (attack)",
        as: 168
      },
      {
        name: "Bite",
        as: 148
      },
      {
        name: "Claw",
        as: 142
      },
      {
        name: "Unknown",
        as: 145
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Stomp"
      }
    ],
    special_abilities: [
      {
        name: "Leap"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (125..181),
    ranged: (93..131),
    bolt: (93..131),
    udf: (147..197),
    bar_td: nil,
    cle_td: (42..45),
    emp_td: (45..53),
    pal_td: nil,
    ran_td: (45..51),
    sor_td: 45,
    wiz_td: nil,
    mje_td: 45,
    mne_td: 45,
    mjs_td: (45..51),
    mns_td: (45..51),
    mnm_td: (45..51),
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
    skin: "a puma paw",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The humpbacked puma is a muscular and athletic animal. Covered with a uniform coat of greyish-brown fur, his long, lithe body is equipped with powerful legs, displaying a proportionately greater difference in the length of the forelegs compared to the extenuated hind legs. The feline's head is topped with rounded ears, and a very long, balancing tail completes the puma's physique."
    ],
    arrival: [
      "A humpbacked puma scampers in!"
    ],
    flee: [
      "A humpbacked puma scampers {direction}.",
      "A humpbacked puma scampers {direction}, mewling in pain."
    ],
    death: [
      "The humpbacked puma lets out a final caterwaul and dies.",
      "The humpbacked puma crumples to the ground and dies."
    ],
    decay: [
      "A humpbacked puma decays into a compost of fangs, fur and claws."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      claw: [
        "A humpbacked puma claws at you!"
      ],
      bite: [
        "A humpbacked puma tries to bite you!"
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
