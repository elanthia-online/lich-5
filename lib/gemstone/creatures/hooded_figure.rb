{
  schema_version: 3,
  name: "hooded figure",
  noun: "figure",
  url: "https://gswiki.play.net/hooded_figure",
  picture: "",
  level: 30,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 238,
  speed: 7,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "The Broken Lands",
      uids: [306016..306048, 487002..487007, 487010..487014, 487016..487016, 487018..487018, 487044..487048]
    },
    {
      name: "unmapped",
      uids: [487015..487015, 487017..487017]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Broadsword"
      },
      {
        name: "Morning star"
      },
      {
        name: "Falchion",
        as: (186..231)
      },
      {
        name: "Short sword",
        as: 231
      }
    ],
    bolt_spells: [
      {
        name: "Cone of Elements (518)",
        as: (182..233)
      },
      {
        name: "Major Cold (907)",
        as: (182..233)
      },
      {
        name: "Major Fire (908)",
        as: (182..233)
      },
      {
        name: "Major Shock (910)",
        as: (182..233)
      },
      {
        name: "Minor Fire (906)",
        as: (182..233)
      },
      {
        name: "Minor Shock (901)",
        as: (182..233)
      },
      {
        name: "Minor Water (903)",
        as: (182..233)
      }
    ],
    warding_spells: [
      {
        name: "Blood Burst (701)",
        cs: (168..195)
      },
      {
        name: "Corrupt Essence (703)",
        cs: (168..195)
      },
      {
        name: "Elemental Blast (409)",
        cs: (168..195)
      },
      {
        name: "Elemental Saturation (413)",
        cs: (168..195)
      },
      {
        name: "Elemental Strike (415)",
        cs: (168..195)
      },
      {
        name: "Immolation (519)",
        cs: (168..195)
      },
      {
        name: "Mana Disruption (702)",
        cs: (168..195)
      },
      {
        name: "Dagger",
        cs: 168
      },
      {
        name: "Falchion",
        cs: 195
      },
      {
        name: "Short sword",
        cs: 195
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Dispel (417)"
      },
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Tremors (909)"
      },
      {
        name: "Weapon Deflection (412)"
      }
    ],
    maneuvers: [
      {
        name: "Gesture"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (140..300),
    ranged: (116..244),
    bolt: (116..244),
    udf: (150..279),
    bar_td: nil,
    cle_td: (131..141),
    emp_td: (136..146),
    pal_td: (112..122),
    ran_td: (111..114),
    sor_td: (118..160),
    wiz_td: nil,
    mje_td: 136,
    mne_td: 136,
    mjs_td: (131..134),
    mns_td: (131..134),
    mnm_td: (122..129),
    defensive_spells: [
      "Elemental Bias (508)",
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Lesser Shroud (120)",
      "Mass Blur (911)",
      "Presence (402)",
      "Prismatic Guard (905)",
      "Spirit Defense (103)",
      "Spirit Fog (106)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)",
      "Thurfel's Ward (503)",
      "Weapon Deflection (412)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a broadsword",
    "a chain hauberk",
    "a dagger",
    "a falchion",
    "a flail",
    "a hooded cloak",
    "a leather breastplate",
    "a mace",
    "a metal breastplate",
    "a quarter staff",
    "a rapier",
    "a reinforced shield",
    "a short sword",
    "a wooden shield",
    "an augmented breastplate",
    "some augmented chain",
    "some brigandine armor",
    "some chain mail",
    "some cuirbouilli leather",
    "some double chain",
    "some double leather",
    "some flowing robes",
    "some full leather",
    "some light leather",
    "some reinforced leather",
    "some studded leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "glimmering blue essence dust",
      "glowing violet essence dust"
    ],
    armaments: [
      "morning star"
    ],
    transmogs: nil
  },
  messaging: {
    description: [
      "It is hard to see much of the hooded figure because of the voluminous hooded cloak. However, the figure does appear to be that of a young human, or humanoid, male. His skin is very pale, almost an opalescent white in color and his eyes are an ominous dull grey. You can see a few locks of curly black hair streaked with stark white tufts concealed by the hood of his cloak. When he glances in your direction, you can feel his gaze almost as a physical blow. He holds himself erect, a tall and imposing figure giving evidence of great pride."
    ],
    arrival: [
      "A hooded figure just arrived.",
      "A hooded figure just arrived, limping.",
      "A hooded figure just came through a small wooden door.",
      "A hooded figure just came through a heavy threadbare curtain.",
      "A hooded figure just came through an ornate black marble arch.",
      "A hooded figure just came through a sturdy iron-bound door.",
      "A hooded figure just came through a threadbare brocade curtain."
    ],
    flee: [
      "A hooded figure heads {direction}."
    ],
    death: [
      "The hooded figure screams one last time and lies still.",
      "The hooded figure falls to the ground and lies still."
    ],
    decay: [
      "A hooded figure decays away."
    ],
    search: [],
    spell_prep: [
      "A hooded figure mutters a few muted syllables."
    ],
    attacks: {
      attack: [
        "A hooded figure gestures at you!",
        "A hooded figure swings {weapon} at you!"
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
