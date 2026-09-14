{
  schema_version: 3,
  name: "water witch",
  noun: "witch",
  url: "https://gswiki.play.net/water_witch",
  picture: "",
  level: 5,
  family: "Witch",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Element-based"
  ],
  bcs: true,
  max_hp: 80,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Vornavian Coast",
      uids: [4202101..4202111]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Spear",
        as: 94
      },
      {
        name: "Gold-edged steel jeddart-axe",
        as: 66
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
    asg: "1N",
    immunities: [],
    melee: (27..43),
    ranged: (16..23),
    bolt: (16..23),
    udf: 97,
    bar_td: 15,
    cle_td: 15,
    emp_td: 15,
    pal_td: (12..15),
    ran_td: 15,
    sor_td: 15,
    wiz_td: nil,
    mje_td: 15,
    mne_td: 15,
    mjs_td: 15,
    mns_td: 15,
    mnm_td: 15,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a spear",
    "a wooden shield"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: nil,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The water witch is never found far from its life-giving oceans. Although the water witch is humanoid in shape, it has well-defined piscatorial features including bright crimson, flaring gills and light green, scaly skin. A spiny, dull red sail stands erect on the top of its head, becoming an angry scarlet when danger approaches. The water witch prefers lonely, shallow bays where it can waylay an occasional single adventurer before returning quickly to the seas."
    ],
    arrival: [
      "A water witch just arrived."
    ],
    flee: [],
    death: [
      "The water witch falls to the ground motionless.",
      "The water witch screams evilly one last time and goes still."
    ],
    decay: [
      "A water witch turns to dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A water witch swings {weapon} at you!",
        "A water witch thrusts with a spear at you!"
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
