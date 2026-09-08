{
  schema_version: 3,
  name: "wood sprite",
  noun: "sprite",
  url: "https://gswiki.play.net/wood_sprite",
  picture: "",
  level: 38,
  family: "Fey",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
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
  max_hp: 238,
  speed: nil,
  height: 3,
  size: "tiny",
  areas: [
    {
      name: "Gyldemar Forest",
      uids: [13031001..13031012, 13031025..13031043, 13031055..13031081]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Jeddart-axe",
        as: (201..214)
      },
      {
        name: "Spear",
        as: 230
      },
      {
        name: "Quarterstaff",
        as: 250
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Call Swarm (615)"
      },
      {
        name: "Lullabye (1005)"
      },
      {
        name: "Sounds (607)"
      },
      {
        name: "Tangleweed (610)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "9N",
    immunities: [],
    melee: (196..353),
    ranged: 107,
    bolt: (156..160),
    udf: (211..371),
    bar_td: (119..124),
    cle_td: (130..140),
    emp_td: (140..150),
    pal_td: (111..120),
    ran_td: (121..127),
    sor_td: (140..149),
    wiz_td: nil,
    mje_td: (146..157),
    mne_td: (146..157),
    mjs_td: (131..141),
    mns_td: (131..141),
    mnm_td: (122..127),
    defensive_spells: [
      "Natural Colors (601)",
      "Phoen's Strength (606)",
      "Resist Elements (602)",
      "Self Control (613)",
      "Spirit Defense (103)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)",
      "Lesser Shroud (120)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a battered helm",
    "a frayed leather helm",
    "a jeddart-axe",
    "a quarter staff",
    "a spear",
    "a torn leather bracers",
    "some tattered bracers"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Glowing violet essence shardPristine sprite's hair",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Appearing more like an animated stick figure than a fleshy humanoid, the slender brown form of the wood sprite stands just under three feet. Her eyes, two sparkling almond-shapes in her wood-like visage, belie a fervent sort of insanity as a frantic, incomprehensible whispering issues from her small mouth."
    ],
    arrival: [
      "Seemingly from nowhere, a wood sprite wanders in!"
    ],
    flee: [
      "A wood sprite glances around and then wanders {direction}!"
    ],
    death: [
      "The wood sprite's eyes grow dim as {pronoun} lifeforce fades away."
    ],
    decay: [
      "A wood sprite crumbles into a pile of dry splinters."
    ],
    search: [],
    spell_prep: [
      "A wood sprite's eyes glow brightly, and {pronoun} motions to you!"
    ],
    attacks: {
      attack: [
        "A wood sprite swings {weapon} at you!"
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
