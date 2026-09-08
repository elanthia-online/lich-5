{
  schema_version: 3,
  name: "triton magus",
  noun: "magus",
  url: "https://gswiki.play.net/triton_magus",
  picture: "",
  level: 102,
  family: "Triton",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: true,
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
  max_hp: 299,
  speed: 3,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Ruined Temple",
      uids: [3031081..3031106]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Arrow",
        as: 431
      },
      {
        name: "Powerful lightning bolt",
        as: 409
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Nature's Fury (635)",
        cs: 433
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Targeting (425)"
      }
    ],
    maneuvers: [
      {
        name: "Feint"
      },
      {
        name: "Spike Thorn (616)"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8",
    immunities: [],
    melee: (345..443),
    ranged: (310..379),
    bolt: (310..379),
    udf: (432..554),
    bar_td: 373,
    cle_td: (430..433),
    emp_td: (406..414),
    pal_td: (362..372),
    ran_td: (371..379),
    sor_td: nil,
    wiz_td: nil,
    mje_td: (464..473),
    mne_td: (464..473),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I",
      "Elemental Defense II",
      "Elemental Defense III",
      "Natural Colors",
      "Resist Elements",
      "Self Control",
      "Sneaking",
      "Spirit Defense"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a dried seaweed-wrapped longbow",
    "a mildewed rough leather quiver"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an iridescent triton hide",
    other: [
      "a bundle of arrows",
      "tiny golden seed"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Moving quietly on wide, webbed feet, the triton magus seems to slip between the shadows, her damp mottled flesh shifting colors with the surroundings. The creature pauses frequently, her flared nostrils quivering as if seeking beings as nearly invisible as herself. A long row of tiny needle-sharp teeth protrudes from grey gums, visible behind her curled, wet lips. A loose robe in varying shades of grey and green covers the magus, hanging just below her twitching tail."
    ],
    arrival: [
      "A triton magus just arrived.",
      "A triton magus slips into hiding.",
      "A triton magus staggers in, dragging {reflexive} along with labored breaths."
    ],
    flee: [],
    death: [
      "The triton magus gurgles once and goes still, a wrathful look on {pronoun} face.",
      "The triton magus collapses to the floor with a splash, gurgling once with a wrathful look on {pronoun} face before expiring.",
      "The triton magus collapses to the ground with a splash, gurgling once with a wrathful look on {pronoun} face before expiring."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A triton magus closes {pronoun} eyes for a moment as {pronoun} slowly raises {pronoun} hands to shoulder-level. You hear and feel a resounding low thrumming sound just as a multitude of sharp pieces of debris splinter off from underfoot, savagely assailing the area!",
      "A triton magus closes {pronoun} eyes for a moment as {pronoun} slowly raises {pronoun} {weapon}. You hear and feel a resounding low thrumming sound just as a multitude of sharp pieces of debris splinter off from underfoot, savagely assailing the area!"
    ],
    attacks: {
      attack: [
        "A triton magus places one hand on top of the other, crossing {pronoun} palms toward you!"
      ],
      fire: [
        "A triton magus fires {weapon} at you!"
      ],
      hurl: [
        "A triton magus hurls {weapon} at you!"
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
