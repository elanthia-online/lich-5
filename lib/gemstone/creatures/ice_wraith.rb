{
  schema_version: 3,
  name: "ice wraith",
  noun: "wraith",
  url: "https://gswiki.play.net/ice_wraith",
  picture: "",
  level: 45,
  family: "Wraith",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead",
    "Element-based"
  ],
  bcs: nil,
  max_hp: 240,
  speed: 4,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Great Mountain Aenatumgana",
      uids: [4561001..4561010]
    },
    {
      name: "Pinefar Forests",
      uids: [4563039..4563060]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Kaskara",
        as: 238
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Point",
        cs: 227
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Point"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (124..312),
    ranged: (121..221),
    bolt: (121..221),
    udf: (177..270),
    bar_td: nil,
    cle_td: (178..187),
    emp_td: (178..187),
    pal_td: (147..157),
    ran_td: (145..153),
    sor_td: (184..193),
    wiz_td: nil,
    mje_td: (197..207),
    mne_td: (197..207),
    mjs_td: (168..186),
    mns_td: (168..186),
    mnm_td: (150..157),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye",
    "a kaskara",
    "a rusting horned helm",
    "a splintered shield",
    "a steel-tipped whip",
    "a tattered robe",
    "some decaying leathers"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "essence of water",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Glistening from head to toe with brilliant clear ice, the ice wraith is a picture of deadly beauty. Long, razor-sharp shards of ice form his claws, and two thin ice stalactites serve as fangs. When illuminated by the sun, the crystalline ice wraith reflects all colors of the rainbow, often mesmerizing his prey, then striking with potent magic."
    ],
    arrival: [
      "An ice wraith glides in surrounded by a cloud of swirling snow!"
    ],
    flee: [
      "An ice wraith withdraws, disengaging from {target}."
    ],
    death: [
      "An ice wraith fades into oblivion."
    ],
    decay: [
      "An ice wraith fades into oblivion."
    ],
    search: [],
    spell_prep: [
      "An ice wraith gestures arcanely."
    ],
    stun_break: [
      "The ice wraith shrugs off the cold."
    ],
    attacks: {
      attack: [
        "An ice wraith swings {weapon} at you!",
        "An ice wraith swings a kaskara at {target}!"
      ],
      bolt: [
        "An ice wraith hurls a seething blast of steam at you!"
      ],
      cast: [
        "An ice wraith points a ghostly finger at you!"
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
