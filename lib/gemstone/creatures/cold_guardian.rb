{
  schema_version: 3,
  name: "cold guardian",
  noun: "guardian",
  url: "https://gswiki.play.net/cold_guardian",
  picture: "",
  level: 34,
  family: "Elemental",
  type: "Elemental",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: false,
  sympathy: true,
  muggable: false,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 240,
  speed: 8,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Icemule Trail",
      uids: [4044131..4044134, 4044136..4044139]
    },
    {
      name: "Ice Plains",
      uids: [4127035..4127045, 7502001..7502015]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 240
      },
      {
        name: "Charge",
        as: 220
      }
    ],
    bolt_spells: [
      {
        name: "Major Cold (907)",
        as: 193
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "7N",
    immunities: [],
    melee: (160..170),
    ranged: (137..163),
    bolt: (137..163),
    udf: 204,
    bar_td: nil,
    cle_td: 116,
    emp_td: (111..117),
    pal_td: (99..102),
    ran_td: 102,
    sor_td: 123,
    wiz_td: nil,
    mje_td: 129,
    mne_td: 129,
    mjs_td: (145..155),
    mns_td: (145..155),
    mnm_td: 102,
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
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Alchemy components, Lockpicks",
      "essence of water"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A swirling column of ice that is somehow animate faces you. A biting cold mist flows around it to chill you and to sink a numbing dampness deep into your bones. Moisture condenses from the very air onto the guardian and pale frost collects on its surface only to grow heavy and break free with a cold, brittle sound that echoes like faint mocking laughter."
    ],
    arrival: [],
    flee: [],
    death: [
      "The cold guardian screams evilly one last time and goes still.",
      "The cold guardian falls to the ground motionless."
    ],
    decay: [
      "A cold guardian turns to dust."
    ],
    search: [],
    spell_prep: [
      "A cold guardian gestures at {target}!"
    ],
    attacks: {
      attack: [
        "A cold guardian gestures at you!",
        "A cold guardian swings {weapon} at you!"
      ],
      bolt: [
        "A cold guardian hurls a freezing ball of pure cold at {target}!"
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
