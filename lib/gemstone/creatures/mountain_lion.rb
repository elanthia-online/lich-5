{
  schema_version: 3,
  name: "mountain lion",
  noun: "lion",
  url: "https://gswiki.play.net/mountain_lion",
  picture: "",
  level: 18,
  family: "Feline",
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
  max_hp: 165,
  speed: 6,
  height: 3,
  size: "medium",
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
        as: (159..165)
      },
      {
        name: "Bite",
        as: (132..168)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Pounce"
      },
      {
        name: "Leap"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [],
    melee: (107..189),
    ranged: (75..133),
    bolt: (75..133),
    udf: (125..184),
    bar_td: nil,
    cle_td: (54..60),
    emp_td: (54..62),
    pal_td: (48..57),
    ran_td: (51..57),
    sor_td: (48..57),
    wiz_td: nil,
    mje_td: (54..60),
    mne_td: (54..60),
    mjs_td: (54..60),
    mns_td: (54..60),
    mnm_td: (51..57),
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
    skin: "a mountain lion's ",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The mountain lion is a muscular and athletic animal. Covered with a uniform coat of reddish-brown fur, her long, lithe body is equipped with powerful legs, displaying a proportionately greater difference in the length of the forelegs compared to the extenuated hind limbs. The feline's head is topped with rounded ears, and a very long, balancing tail completes the lion's physique."
    ],
    arrival: [
      "A mountain lion scampers in!",
      "A mountain lion scampers in, mewling in pain!",
      "A mountain lion pounces to the ground in front of you!"
    ],
    flee: [
      "A mountain lion scampers {direction}.",
      "A mountain lion scampers {direction}, mewling in pain."
    ],
    death: [
      "The mountain lion crumples to the ground and dies.",
      "The mountain lion lets out a final caterwaul and dies."
    ],
    decay: [
      "A mountain lion decays into a compost of fangs, fur and claws."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "The mountain lion throws up copious amounts of blood and what appears to be an internal organ!"
      ],
      claw: [
        "A mountain lion claws at you!"
      ],
      bite: [
        "A mountain lion tries to bite you!"
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
