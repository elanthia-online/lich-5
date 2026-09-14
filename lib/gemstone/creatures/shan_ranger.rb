{
  schema_version: 3,
  name: "shan ranger",
  noun: "ranger",
  url: "https://gswiki.play.net/shan_ranger",
  picture: "",
  level: 42,
  family: "Shan",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
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
  max_hp: 238,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Vornavian Coast",
      uids: [4218301..4218325]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Longsword",
        as: (276..294)
      }
    ],
    bolt_spells: [
      {
        name: "Web (118)",
        as: 276
      }
    ],
    warding_spells: [
      {
        name: "Wild Entropy (603)",
        cs: 188
      },
      {
        name: "Web (118)",
        cs: 194
      }
    ],
    offensive_spells: [
      {
        name: "Phoen's Strength (606)"
      },
      {
        name: "Spirit Strike (117)"
      },
      {
        name: "Spike Thorn (616)"
      },
      {
        name: "Tangleweed (610)"
      },
      {
        name: "Sounds (607)"
      },
      {
        name: "Call Swarm (615)"
      }
    ],
    maneuvers: [
      {
        name: "Disarm"
      },
      {
        name: "Lash"
      },
      {
        name: "Web"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "11",
    immunities: [],
    melee: (221..377),
    ranged: (231..264),
    bolt: (231..264),
    udf: 373,
    bar_td: 135,
    cle_td: (143..153),
    emp_td: (142..152),
    pal_td: (133..142),
    ran_td: (133..142),
    sor_td: (160..166),
    wiz_td: nil,
    mje_td: (159..165),
    mne_td: (159..165),
    mjs_td: (142..161),
    mns_td: (142..161),
    mnm_td: (148..157),
    defensive_spells: [
      "Mobility (618)",
      "Natural Colors (601)",
      "Self Control (613)",
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a diamond-hilted longsword",
    "a leather skullcap",
    "a silvery longsword",
    "a small steel buckler",
    "a square lantern shield",
    "some forest green leathers",
    "some studded green leathers"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Tiny golden seed",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The shan ranger stands in a half-crouch, his long, knotty legs giving him that lanky, dangerous look of a wolf. Walking upright, the body covered with mottled grey fur and his long arms conclude in large, clawed hands with semi-opposable thumbs. The shan ranger's dog-like visage is fierce, with slavering jaws and eyes that glow like something out of a bad dream."
    ],
    arrival: [],
    flee: [
      "A shan ranger pads {direction}.",
      "A shan ranger limps {direction}."
    ],
    death: [
      "The shan ranger howls out one last time and dies.",
      "The shan ranger yips in pain as {pronoun} falls to the ground motionless.",
      "A shan ranger's body shimmers slightly.  Suddenly, {pronoun} features cave in, falling grotesquely into a haunting visage of decay, before abruptly fraying to a pile of fur and fangs that marks the spot of {pronoun} death like a silhouette."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A shan ranger utters a phrase of magic."
    ],
    stand: [
      "A shan ranger scrambles to {pronoun} feet!"
    ],
    attacks: {
      hurl: [
        "A shan ranger throws a diamond-hilted longsword at you!"
      ],
      attack: [
        "A shan ranger swings {weapon} at you!",
        "A shan ranger nods at you!"
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
