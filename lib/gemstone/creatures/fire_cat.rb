{
  schema_version: 3,
  name: "fire cat",
  noun: "cat",
  url: "https://gswiki.play.net/fire_cat",
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
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Magical",
    "Element-based"
  ],
  bcs: true,
  max_hp: 165,
  speed: 9,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "Lysierian Hills",
      uids: [92032..92041, 92120..92129]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (135..164)
      },
      {
        name: "Bite",
        as: (157..170)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Pounce"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [
      "Fire"
    ],
    melee: (83..155),
    ranged: (76..111),
    bolt: (76..111),
    udf: (116..175),
    bar_td: 54,
    cle_td: (48..57),
    emp_td: (54..58),
    pal_td: (51..60),
    ran_td: (51..60),
    sor_td: (48..60),
    wiz_td: 54,
    mje_td: 54,
    mne_td: 54,
    mjs_td: (51..60),
    mns_td: (51..60),
    mnm_td: (48..57),
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
    skin: "a fire cat claw",
    other: "essence of fire",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The fire cat is a sleek cat, a real beauty to behold. It is fairly large, standing roughly head-high to a halfling. Its fur ranges from red to orange in color and it has long claws that have a metallic glint."
    ],
    arrival: [
      "A fire cat scampers in!"
    ],
    flee: [
      "A fire cat scampers {direction}.",
      "A fire cat scampers {direction}, mewling in pain."
    ],
    death: [
      "The fire cat lets out a final caterwaul and dies.",
      "The fire cat crumples to the ground and dies."
    ],
    decay: [
      "A fire cat decays into a compost of fangs, fur and claws."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      claw: [
        "A fire cat claws at you!"
      ],
      bite: [
        "A fire cat tries to bite you!"
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
