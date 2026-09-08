{
  schema_version: 3,
  name: "Illoke jarl",
  noun: "jarl",
  url: "https://gswiki.play.net/illoke_jarl",
  picture: "",
  level: 89,
  family: "Giant",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 600,
  speed: nil,
  height: 23,
  size: "huge",
  areas: [
    {
      name: "Bowels of Thanatoph",
      uids: [4293016..4293057]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Fist",
        as: 392
      },
      {
        name: "Hammer",
        as: (422..435)
      },
      {
        name: "Foot",
        as: 405
      },
      {
        name: "Heavy earthen fists",
        as: 419
      },
      {
        name: "Huge rock",
        as: 434
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Divine Strike (1615)",
        cs: (363..375)
      },
      {
        name: "Heavy black stone hammer",
        cs: 366
      },
      {
        name: "Slate grey stone hammer",
        cs: 338
      },
      {
        name: "Charge",
        cs: 363
      }
    ],
    offensive_spells: [
      {
        name: "Spirit Strike (117)"
      }
    ],
    maneuvers: [
      {
        name: "Mstrike"
      },
      {
        name: "Divine Wrath"
      },
      {
        name: "Feint"
      },
      {
        name: "Ground Slam"
      },
      {
        name: "Charge"
      },
      {
        name: "Ethereal Wave"
      },
      {
        name: "Shield Charge"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16N",
    immunities: [],
    melee: (256..268),
    ranged: (251..395),
    bolt: (251..395),
    udf: (470..699),
    bar_td: 336,
    cle_td: (364..373),
    emp_td: (354..363),
    pal_td: (310..319),
    ran_td: (310..319),
    sor_td: (373..382),
    wiz_td: nil,
    mje_td: 397,
    mne_td: 397,
    mjs_td: (351..366),
    mns_td: (351..366),
    mnm_td: (280..289),
    defensive_spells: [
      "Divine Shield",
      "Fasthr's Reward",
      "Lesser Shroud",
      "Song of Unravelling (1013)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a grey stone crescent symbol",
    "a heavy black stone hammer",
    "a massive iron-banded greatshield",
    "a massive pitted iron pavis",
    "a slate grey stone hammer"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "radiant crimson essence shard",
      "essence of earth"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The hulking frame of the Illoke jarl towers high overhead, ready to obliterate any who would intrude upon his territory. Craggy, deep grey skin sheathes him in a natural armor, with little hindrance to his movements. A pair of piercing black eyes stare out with contempt, barely distinguishable against his dark complexion. In contrast, a shimmering crimson symbol of Illoke is chiseled deep into his forehead, radiating a dull red glow."
    ],
    arrival: [],
    flee: [
      "An Illoke jarl sinks into the ground and flows {direction}."
    ],
    death: [
      "The Illoke jarl grumbles in pain one last time before lying still.",
      "The Illoke jarl shudders one last time before lying still."
    ],
    decay: [
      "An Illoke jarl cracks and collapses into a pile of craggy dark rock that rapidly disappears without a trace.",
      "Tiny fissures quickly spread over the entire form of a greater earth elemental.  Within moments, it crumbles into a pile of dirt and rubble.",
      "Tiny fissures quickly spread over the entire form of an earth elemental.  Within moments, it crumbles into a pile of dirt and rubble."
    ],
    search: [],
    spell_prep: [
      "An Illoke jarl eyes glow with silvery grey light, and then everything around you shimmers to match the argentine color.",
      "An Illoke jarl mutters a prayer to {pronoun} god.",
      "An Illoke jarl chants, \"Master of the dark, cold and deep...\"",
      "An Illoke jarl's eyes glow with silvery grey light, and then everything around you shimmers to match the argentine color."
    ],
    stand: [
      "An Illoke jarl blinks dazedly a moment before shaking off the stun!"
    ],
    attacks: {
      attack: [
        "An Illoke jarl pounds at you with {pronoun} fist!",
        "An Illoke jarl stomps at you with {pronoun} foot!",
        "An Illoke jarl swings {weapon} at you!",
        "An Illoke jarl punches {pronoun} fist into the ground!",
        "The Illoke jarl slams into you, and you are sent careening to the ground!",
        "An Illoke jarl summons the wrath of {pronoun} god while pointing at you!"
      ],
      hurl: [
        "An Illoke jarl throws {weapon} at you!"
      ],
      shield_charge: [
        "An Illoke jarl charges forward at you with {pronoun} pitted iron pavis and attempts a shield charge!",
        "An Illoke jarl charges forward at you with {pronoun} iron-banded greatshield and attempts a shield charge!"
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
