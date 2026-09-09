{
  schema_version: 3,
  name: "stone troll",
  noun: "troll",
  url: "https://gswiki.play.net/stone_troll",
  picture: "",
  level: 55,
  family: "Troll",
  type: "Biped",
  undead: false,
  blood: true,
  bones: nil,
  limbs: true,
  witherable: true,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: 11,
  size: "large",
  areas: [
    {
      name: "Stone Valley",
      uids: [4291027..4291043, 4291046..4291050, 4291053..4291058]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Thrown",
        as: 321
      },
      {
        name: "War hammer",
        as: 321
      },
      {
        name: "Foot",
        as: 296
      },
      {
        name: "Giant stone hammer",
        as: 298
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Unbalance",
        cs: 214
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Ground slap"
      },
      {
        name: "Ground stomp"
      },
      {
        name: "Stone spit"
      },
      {
        name: "Ground Slam"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "16N",
    immunities: [],
    melee: (492..613),
    ranged: (182..186),
    bolt: (182..186),
    udf: 212,
    bar_td: (183..195),
    cle_td: (203..206),
    emp_td: (198..207),
    pal_td: (172..175),
    ran_td: 175,
    sor_td: (216..228),
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: (204..216),
    mns_td: (204..216),
    mnm_td: (165..174),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a flail",
    "a reinforced shield",
    "a war hammer"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "small troll tooth, large troll tooth",
      "essence of earth"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Towering above you, the stone troll is an ugly, brutish looking creature. Its marbled grey skin is covered with pocks and divots. This lumpy grotesque troll grins maniacally at you, sending cracks and fissures across its face."
    ],
    arrival: [
      "The ground shakes as an enraged stone troll stomps in!"
    ],
    flee: [
      "There is a loud rumbling as a stone troll crawls out of the ground!"
    ],
    death: [
      "The stone troll topples to the ground motionless.",
      "The stone troll shudders violently for a moment, then goes still."
    ],
    decay: [
      "A stone troll sinks into the ground, leaving nothing behind."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A stone troll flails {pronoun} arms about angrily, shaking off the stun!"
    ],
    attacks: {
      attack: [
        "A stone troll stomps at you with {pronoun} foot!",
        "A stone troll swings {weapon} at you!"
      ],
      claw: [
        "A stone troll claws {pronoun} way into the ground and burrows {direction}."
      ],
      hurl: [
        "A stone troll throws a flail at you!"
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
