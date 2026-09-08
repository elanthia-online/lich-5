{
  schema_version: 3,
  name: "treekin druid",
  noun: "druid",
  url: "https://gswiki.play.net/treekin_druid",
  picture: "",
  level: 83,
  family: "Tree",
  type: "Plantlife",
  undead: false,
  blood: true,
  bones: false,
  limbs: true,
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
  speed: nil,
  height: 8,
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
        as: 400
      },
      {
        name: "Root lash",
        as: 400
      },
      {
        name: "Root slam",
        as: 400
      },
      {
        name: "Large boulder",
        as: 265
      },
      {
        name: "Leafy fist",
        as: 370
      }
    ],
    bolt_spells: [
      {
        name: "Hurl Boulder (510)",
        as: 350
      }
    ],
    warding_spells: [
      {
        name: "Searing Light (135)",
        cs: 340
      }
    ],
    offensive_spells: [
      {
        name: "Call Swarm (615)"
      },
      {
        name: "Spirit Dispel (119)"
      },
      {
        name: "Spike Thorn (616)"
      },
      {
        name: "Phoen's Strength (606)"
      }
    ],
    maneuvers: [
      {
        name: "Whirlwind of leaves (or pollen)"
      },
      {
        name: "Grab"
      },
      {
        name: "Leaf Whirlwind"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16",
    immunities: [],
    melee: (361..434),
    ranged: (205..222),
    bolt: (205..222),
    udf: 390,
    bar_td: 329,
    cle_td: (355..361),
    emp_td: 361,
    pal_td: (305..311),
    ran_td: (308..314),
    sor_td: (365..379),
    wiz_td: nil,
    mje_td: 389,
    mne_td: 389,
    mjs_td: (346..355),
    mns_td: (346..355),
    mnm_td: 261,
    defensive_spells: [
      "Barkskin",
      "Natural Colors (601)",
      "Resist Elements (602)"
    ],
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
    skin: "mossy beard",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Standing approximately eight feet tall, the treekin druid glares at you with malevolent intent. Lambent yellow eyes and thick leg-shaped roots make it clear that this is no ordinary tree. Leaves cover the druid from head to trunk, with two arm-shaped branches protruding from the canopy. A long mossy beard dangles below a crooked knothole under the eyes, giving gnarled look to an already imposing foe."
    ],
    arrival: [
      "With a rustle of leaves, a treekin druid lumbers in!",
      "A treekin druid lumbers in!",
      "A treekin druid lumbers in, leaving a path of leaves behind it!"
    ],
    flee: [
      "A treekin druid lumbers {direction}.",
      "A treekin druid lumbers {direction}, leaving a trail of leaves of behind it.",
      "A treekin druid shudders and lumbers {direction}, leaving a trail of sap and leaves of behind it.",
      "A treekin druid lumbers {direction}, leaving a path of leaves behind {pronoun}!"
    ],
    death: [
      "The druid teeters and then topples to the ground!"
    ],
    decay: [
      "The layer of bark on a treekin druid hardens and absorbs the attack!  The bark crackles as it crumbles to dust.",
      "The layer of bark on a treekin druid hardens and absorbs the magical energy!  The bark crackles as it crumbles to dust.",
      "A treekin druid decays into compost.",
      "The treekin druid crumbles to the ground!"
    ],
    search: [],
    spell_prep: [
      "A treekin druid gestures at you! Suddenly, roots spring from the ground and attempt to grab you!",
      "A treekin druid gestures and then hurls a whirlwind of leaves at you!",
      "A treekin druid groans an incantation."
    ],
    attacks: {
      attack: [
        "A treekin druid lashes {weapon} at you!",
        "A treekin druid raises a large root and slams it down at you!",
        "A treekin druid pounds at you with a leafy fist!"
      ],
      hurl: [
        "A treekin druid hurls {weapon} at you!"
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
