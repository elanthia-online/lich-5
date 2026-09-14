{
  schema_version: 3,
  name: "moulis",
  noun: "moulis",
  url: "https://gswiki.play.net/moulis",
  picture: "",
  level: 75,
  family: "Plant",
  type: "Plantlife",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Living",
    "Magical",
    "Boss"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: 5,
  size: "large",
  areas: [
    {
      name: "Maaghara Tower",
      uids: [13022026..13022060]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Attack",
        as: 380
      },
      {
        name: "Powerful lightning bolt",
        as: 277
      }
    ],
    bolt_spells: [
      {
        name: "Cone of Elements (518)"
      }
    ],
    warding_spells: [
      {
        name: "Cold Snap (512)",
        cs: (331..349)
      },
      {
        name: "Immolation (519)"
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Splinter Barrage"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (182..320),
    ranged: (171..223),
    bolt: (171..223),
    udf: (298..395),
    bar_td: (264..270),
    cle_td: (282..297),
    emp_td: (276..286),
    pal_td: (238..248),
    ran_td: (238..248),
    sor_td: (299..317),
    wiz_td: nil,
    mje_td: (316..332),
    mne_td: (316..332),
    mjs_td: (286..311),
    mns_td: (286..311),
    mnm_td: (235..245),
    defensive_spells: [
      "Elemental Bias (508)",
      "Elemental Deflection (507)",
      "Stone Skin (520)",
      "Strength (509)"
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
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Waving its myriad of oddly flexible, root-like appendages, the moulis scuttles about its home area. It is not known what the moulis searches for, as observations have usually yielded a quick death for the observer, yet it is known that the moulis is an intelligent, lethal foe capable of commanding the forces of magic as well as a powerful physical attack. It appears to be nothing more than a writhing mass of tubers, roots and thin hair strands in various shades of brown--until a vicious attack springs from the center of the creature."
    ],
    arrival: [
      "A moulis scuttles in and stops, {pronoun} fibrous hair strands waving frantically to and fro!"
    ],
    flee: [
      "A moulis moves northwest in a half-scuttling, half-stumbling manner, as {pronoun} appendages do not seem to be properly coordinated.",
      "A moulis moves northeast in a half-scuttling, half-stumbling manner, as {pronoun} appendages do not seem to be properly coordinated.",
      "A moulis moves south in a half-scuttling, half-stumbling manner, as {pronoun} appendages do not seem to be properly coordinated.",
      "A moulis scuttles west, {pronoun} appendages clacking and scraping as {pronoun} goes.",
      "A moulis scuttles south, {pronoun} appendages clacking and scraping as {pronoun} goes.",
      "A moulis scuttles east, {pronoun} appendages clacking and scraping as {pronoun} goes.",
      "A moulis scuttles north, {pronoun} appendages clacking and scraping as {pronoun} goes."
    ],
    death: [
      "The moulis twitches violently, then dies.",
      "The moulis flails wildly for a moment before going still, its appendages dropping lifelessly to the ground.",
      "The moulis flails wildly for a moment before collapsing, {pronoun} appendages dropping lifelessly to the ground."
    ],
    decay: [
      "A moulis crumbles into a putrid compost.",
      "A nebulous moulis crumbles into a putrid compost.",
      "An indistinct moulis crumbles into a putrid compost.",
      "A drab moulis crumbles into a putrid compost.",
      "A dreary moulis crumbles into a putrid compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      bite: [
        "A moulis snaps two elongated fibers around you!"
      ],
      attack: [
        "A moulis extrudes a flattened fiber and swings it at you!"
      ],
      hurl: [
        "A moulis hurls {weapon} at you!"
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
    triggers: {},
    frenzy: "A moulis slides side to side in an agitated frenzy."
  }
}
