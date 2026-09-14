{
  schema_version: 3,
  name: "black leopard",
  noun: "leopard",
  url: "https://gswiki.play.net/black_leopard",
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
  max_hp: 138,
  speed: 12,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Grasslands",
      uids: [14012050..14012070, 14012150..14012165]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (134..168)
      },
      {
        name: "Bite",
        as: (128..168)
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
    melee: (85..151),
    ranged: (75..100),
    bolt: (75..100),
    udf: (107..146),
    bar_td: 45,
    cle_td: (39..51),
    emp_td: (45..53),
    pal_td: (39..48),
    ran_td: (45..51),
    sor_td: (42..51),
    wiz_td: nil,
    mje_td: (39..45),
    mne_td: (39..45),
    mjs_td: (42..57),
    mns_td: (42..57),
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
    skin: "a black leopard paw",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "At first glance, the black leopard has pure black fur but upon the shifting of light, faint auburn rosette patterns fade in and out of sight against the sleek darkness. The only visible part of the leopard when she's stealthily hidden in the wilds is her deeply-toned amber eyes, which are always gazing warily at her surroundings. With the ability to retract her claws into her large padded paws, the black leopard is able to conceal her movement and stalk silently behind her prey with great success."
    ],
    arrival: [
      "A black leopard scampers in!",
      "A black leopard scampers in, mewling in pain!",
      "A black leopard pounces to the ground in front of you!"
    ],
    flee: [
      "A black leopard scampers {direction}.",
      "A black leopard scampers {direction}, mewling in pain."
    ],
    death: [
      "The black leopard lets out a final caterwaul and dies.",
      "The black leopard crumples to the ground and dies."
    ],
    decay: [
      "A black leopard decays into a compost of fangs, fur and claws."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      claw: [
        "A black leopard claws at you!"
      ],
      bite: [
        "A black leopard tries to bite you!"
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
