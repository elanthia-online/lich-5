{
  schema_version: 3,
  name: "treekin warrior",
  noun: "warrior",
  url: "https://gswiki.play.net/treekin_warrior",
  picture: "",
  level: 80,
  family: "Tree",
  type: "Plantlife",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Magical"
  ],
  bcs: true,
  max_hp: 400,
  speed: 7,
  height: 16,
  size: "large",
  areas: [
    {
      name: "Red Forest",
      uids: [480246..480248, 480250..480260, 17006246..17006248, 17006250..17006260]
    },
    {
      name: "unmapped",
      uids: [480249..480249, 17006249..17006249]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound",
        as: 390
      },
      {
        name: "Root lash",
        as: 390
      },
      {
        name: "Root slam",
        as: 390
      },
      {
        name: "Leafy fist",
        as: 355
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Twin Hammerfists"
      },
      {
        name: "Caber toss"
      },
      {
        name: "Grab"
      },
      {
        name: "Sap Spit"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "17",
    immunities: [
      "Stun"
    ],
    melee: (154..300),
    ranged: (125..283),
    bolt: (125..283),
    udf: (265..557),
    bar_td: 312,
    cle_td: 334,
    emp_td: (317..326),
    pal_td: (268..277),
    ran_td: (268..277),
    sor_td: (337..343),
    wiz_td: nil,
    mje_td: (349..408),
    mne_td: (349..408),
    mjs_td: 349,
    mns_td: 349,
    mnm_td: 252,
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
    skin: "blood-stained bark",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Standing approximately twelve feet tall, the treekin warrior towers menacingly before you. Lambent yellow eyes and thick leg-shaped roots make it clear that this is no ordinary tree. Leaves cover the warrior from head to trunk, with two arm-shaped branches protruding from the canopy. Numerous gashes and chips indicate that this particular specimen has seen much combat in the past."
    ],
    arrival: [
      "With a rustle of leaves, a treekin warrior lumbers in!",
      "A treekin warrior lumbers in!",
      "A treekin warrior shudders as it lumbers in, leaving a path of sap and leaves behind it!",
      "A treekin warrior lumbers in, leaving a path of leaves behind it!"
    ],
    flee: [
      "A treekin warrior shudders and lumbers {direction}, leaving a trail of sap and leaves of behind it.",
      "A treekin warrior lumbers {direction}.",
      "A treekin warrior lumbers {direction}, leaving a trail of leaves of behind it.",
      "A treekin warrior lumbers {direction}, leaving a path of leaves behind {pronoun}!"
    ],
    death: [
      "The warrior teeters and then topples to the ground!"
    ],
    decay: [
      "A treekin warrior decays into compost.",
      "The layer of bark on a treekin warrior hardens and absorbs the attack!  The bark crackles as it crumbles to dust.",
      "The treekin warrior crumbles to the ground!"
    ],
    search: [
      "A treekin warrior sheds a large number of leaves, as {pronoun} glances around apprehensively."
    ],
    spell_prep: [],
    attacks: {
      attack: [
        "A treekin warrior lashes {weapon} at you!",
        "A treekin warrior pounds at you with a leafy fist!",
        "A treekin warrior raises a large root and slams it down at you!",
        "A treekin warrior strikes out at you with all of {pronoun} might!",
        "A treekin warrior suddenly spits a gob of sap directly at you!",
        "A treekin warrior attempts to grab you!"
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
