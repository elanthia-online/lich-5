{
  schema_version: 3,
  name: "forest ogre",
  noun: "ogre",
  url: "https://gswiki.play.net/forest_ogre",
  picture: "",
  level: 17,
  family: "Ogre",
  type: "Biped",
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
  max_hp: 219,
  speed: 8,
  height: 9,
  size: "large",
  areas: [
    {
      name: "Vornavian Coast",
      uids: [4218201..4218221]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 178
      },
      {
        name: "Falchion",
        as: (160..186)
      },
      {
        name: "Pound",
        as: 178
      },
      {
        name: "Stomp",
        as: 178
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tackle"
      },
      {
        name: "Pounce"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "17",
    immunities: [],
    melee: (81..175),
    ranged: (64..96),
    bolt: (64..96),
    udf: (128..192),
    bar_td: (45..51),
    cle_td: (51..57),
    emp_td: (51..59),
    pal_td: (45..54),
    ran_td: (51..57),
    sor_td: 51,
    wiz_td: nil,
    mje_td: 51,
    mne_td: 51,
    mjs_td: (51..57),
    mns_td: (51..57),
    mnm_td: (45..54),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a falchion",
    "a metal breastplate",
    "a wooden shield"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an ogre tusk",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The forest ogre is similar to its troll cousins, being very large, very strong, and very stupid. However, two differences are immediately noticeable. The forest ogre moves nearly silently, not in the heavy, lumbering gait of its cousins, and it does not smell nearly as bad, perhaps due to its constant contact with the pine sap and needles of the forest conifers. It is still just as dangerous."
    ],
    arrival: [
      "A forest ogre just arrived.",
      "A forest ogre just arrived, limping badly."
    ],
    flee: [
      "A forest ogre runs {direction}.",
      "A forest ogre limps {direction}."
    ],
    death: [
      "The forest ogre falls to the ground and dies.",
      "The forest ogre screams one last time and dies."
    ],
    decay: [
      "A forest ogre decays into a heap of pine-scented compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A forest ogre swings {weapon} at you!"
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
