{
  schema_version: 3,
  name: "bobcat",
  noun: "bobcat",
  url: "https://gswiki.play.net/bobcat",
  picture: "",
  level: 5,
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
  max_hp: 60,
  speed: 6,
  height: 2,
  size: "small",
  areas: [
    {
      name: "The Toadwort",
      uids: [14007024..14007041]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite (attack)",
        as: 80
      },
      {
        name: "Claw (attack)",
        as: 90
      },
      {
        name: "Charge (attack)",
        as: 90
      },
      {
        name: "Bite",
        as: 72
      },
      {
        name: "Claw",
        as: 81
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
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [],
    melee: (26..65),
    ranged: (27..33),
    bolt: (27..33),
    udf: (60..93),
    bar_td: nil,
    cle_td: 15,
    emp_td: 15,
    pal_td: (12..15),
    ran_td: 15,
    sor_td: 15,
    wiz_td: nil,
    mje_td: 15,
    mne_td: 15,
    mjs_td: 39,
    mns_td: 39,
    mnm_td: 15,
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
    skin: "a bobcat claw",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Twice the size of a domestic cat, the bobcat is covered in dense, thick fur varying from soft greys to light reddish brown. The fur along the middle back is darker, while her underparts are snowy white. Deep brown spots mark the bobcat's pelt but a predominent white spot on the back of her dark triangular ears make her easily recognizable when gathered with other wild cats. Whisking back and forth with her short banded tail, the bobcat seems anxious to pounce on her next prey."
    ],
    arrival: [
      "A bobcat scampers in!"
    ],
    flee: [
      "A bobcat scampers {direction}.",
      "A bobcat scampers {direction}, mewling in pain."
    ],
    death: [
      "The bobcat crumples to the ground and dies.",
      "The bobcat lets out a final caterwaul and dies."
    ],
    decay: [
      "A bobcat decays into a compost of fangs, fur and claws."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      claw: [
        "A bobcat claws at you!"
      ],
      bite: [
        "A bobcat tries to bite you!"
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
