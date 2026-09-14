{
  schema_version: 3,
  name: "caedera",
  noun: "caedera",
  url: "https://gswiki.play.net/caedera",
  picture: "",
  level: 82,
  family: "Worm",
  type: "Worm",
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
  max_hp: 600,
  speed: 10,
  height: 3,
  size: "large",
  areas: [
    {
      name: "The Rift",
      uids: [4567001..4567055]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (369..411)
      },
      {
        name: "Charge (attack)"
      },
      {
        name: "Ensnare (attack)"
      },
      {
        name: "Charge",
        as: 421
      },
      {
        name: "Ensnare",
        as: 421
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Burrow"
      },
      {
        name: "Burrow Ambush"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (301..414),
    ranged: (288..388),
    bolt: (288..388),
    udf: (380..450),
    bar_td: nil,
    cle_td: 323,
    emp_td: (305..311),
    pal_td: (261..267),
    ran_td: 264,
    sor_td: (326..338),
    wiz_td: nil,
    mje_td: (345..354),
    mne_td: (345..354),
    mjs_td: (305..311),
    mns_td: (305..311),
    mnm_td: (246..252),
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
    "a bruised right eye"
  ],
  treasure: {
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a caedera's ",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The caedera looms malevolently over its prey. Yellow ichor drips from its slavering jaws as its massive head lolls blindly from side to side. Keen senses of smell and sound lead this gargantuan worm to the location of its next meal. Its segmented body contracts and expands powerfully, allowing the beast to burrow through rock and soil with the same ease that other creatures move through the air. Each segment is dark orange with mottled brown spots, though the rings where the segments join are a charcoal grey."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A caedera charges at you!",
        "A caedera tries to ensnare you!"
      ],
      bite: [
        "A caedera tries to bite you!"
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
