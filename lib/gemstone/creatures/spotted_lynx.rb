{
  schema_version: 3,
  name: "spotted lynx",
  noun: "lynx",
  url: "https://gswiki.play.net/spotted_lynx",
  picture: "",
  level: 6,
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
  max_hp: 69,
  speed: 6,
  height: 2,
  size: "small",
  areas: [
    {
      name: "Yander's Farm",
      uids: [14005023..14005025, 14005027..14005036]
    },
    {
      name: "Ocoma Vale",
      uids: [4300001..4300025]
    },
    {
      name: "Central Caravansary",
      uids: [4748310..4748312, 4748321..4748321]
    },
    {
      name: "unmapped",
      uids: [4748313..4748320]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 92
      },
      {
        name: "Charge",
        as: (92..102)
      },
      {
        name: "Claw",
        as: (91..102)
      },
      {
        name: "Unknown",
        as: 102
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
    melee: (26..77),
    ranged: (26..41),
    bolt: (26..41),
    udf: (66..101),
    bar_td: 18,
    cle_td: 18,
    emp_td: 18,
    pal_td: (15..18),
    ran_td: 18,
    sor_td: 18,
    wiz_td: nil,
    mje_td: 18,
    mne_td: 18,
    mjs_td: 18,
    mns_td: 18,
    mnm_td: 18,
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
    skin: "a lynx pelt",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The medium-sized lynx possesses a lush coat, greyish-white marked with a pattern of black spots and a dark dorsal stripe. Black tufts top both of the lynx's large ears and her jaws sport long whiskery fur, giving the animals a mischievous look. Her black-tipped tail is only a few inches long and it whips back and forth nervously as the lynx moves."
    ],
    arrival: [],
    flee: [
      "A spotted lynx darts {direction}."
    ],
    death: [
      "The spotted lynx crumples to the ground and dies.",
      "The spotted lynx lets out a final caterwaul and dies."
    ],
    decay: [
      "A spotted lynx decays into a compost of fangs, fur and claws."
    ],
    search: [],
    spell_prep: [
      "A spotted lynx hisses loudly!"
    ],
    attacks: {
      attack: [
        "A spotted lynx charges at you!"
      ],
      claw: [
        "A spotted lynx claws at you!"
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
