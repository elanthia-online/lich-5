{
  schema_version: 3,
  name: "storm giant",
  noun: "giant",
  url: "https://gswiki.play.net/storm_giant",
  picture: "",
  level: 39,
  family: "Giant",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Element-based"
  ],
  bcs: true,
  max_hp: 400,
  speed: 8,
  height: 12,
  size: "huge",
  areas: [
    {
      name: "Stormpeak",
      uids: [13150201..13150220]
    },
    {
      name: "Upper Trollfang",
      uids: [16065..16071]
    },
    {
      name: "Ice Plains",
      uids: [4127035..4127045]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Morning star",
        as: 247
      },
      {
        name: "Spear",
        as: (197..247)
      },
      {
        name: "Weathered huge zorchar maul",
        as: 252
      }
    ],
    bolt_spells: [
      {
        name: "Major Shock (910)",
        as: 195
      },
      {
        name: "Minor Water (903)",
        as: 195
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Call Wind (912)"
      },
      {
        name: "Gas cloud"
      }
    ],
    maneuvers: [
      {
        name: "Ground stomp"
      },
      {
        name: "Wind blast"
      },
      {
        name: "Ground Slam"
      },
      {
        name: "Thunderclap"
      },
      {
        name: "Wind Rush"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (136..176),
    ranged: (127..209),
    bolt: (127..209),
    udf: (175..216),
    bar_td: nil,
    cle_td: (145..155),
    emp_td: (145..155),
    pal_td: (123..133),
    ran_td: (123..133),
    sor_td: (155..163),
    wiz_td: nil,
    mje_td: (162..167),
    mne_td: (162..167),
    mjs_td: (145..155),
    mns_td: (145..155),
    mnm_td: (117..122),
    defensive_spells: [
      "Spirit Defense (103)",
      "Spirit Warding I (101)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a morning star",
    "a reinforced shield",
    "a spear",
    "a weathered huge zorchar maul"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a giant skin",
    other: "essence of air",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The storm giant's regal bearing and calm demeanor stand in sharp contrast to the raging tempest surrounding it. Standing taller than the tallest giantman, the storm giant stares at others with dull grey eyes that refuse to reflect the sparks of electricity that crackle out from them."
    ],
    arrival: [
      "A storm giant lumbers in, surrounded by a raging storm!"
    ],
    flee: [
      "A storm giant lumbers {direction}, surrounded by a raging storm!",
      "A storm giant lumbers {direction}, surrounded by a raging storm."
    ],
    death: [
      "The storm giant howls in agony one last time and dies.",
      "The storm giant twitches violently, then dies.",
      "The storm giant crumples to the ground motionless."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    stand: [
      "A storm giant throws {pronoun} head back and roars in anger, shaking off the stun!"
    ],
    attacks: {
      attack: [
        "A storm giant claps {pronoun} hands together in front of you!",
        "A storm giant swings {weapon} at you!",
        "A storm giant thrusts with a spear at you!"
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
