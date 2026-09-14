{
  schema_version: 3,
  name: "bog spectre",
  noun: "spectre",
  url: "https://gswiki.play.net/bog_spectre",
  picture: "",
  level: 47,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "Fethayl Bog",
      uids: [13038001..13038031]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (242..269)
      },
      {
        name: "Ensnare",
        as: (220..275)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Corrupt Essence (703)",
        cs: 226
      },
      {
        name: "Disintegrate (705)"
      },
      {
        name: "Grasp of the Grave (709)"
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Gaze Attack"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "5",
    immunities: [],
    melee: (175..308),
    ranged: (185..268),
    bolt: (185..268),
    udf: (216..319),
    bar_td: 182,
    cle_td: (179..188),
    emp_td: (181..190),
    pal_td: (150..160),
    ran_td: (155..160),
    sor_td: (195..205),
    wiz_td: nil,
    mje_td: (186..204),
    mne_td: (186..204),
    mjs_td: (184..194),
    mns_td: (184..194),
    mnm_td: (157..167),
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Spirit Defense (103)",
      "Spirit Warding I (101)",
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
    "some rotting black leathers"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Glowing violet essence shard",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The bog spectre's misty form fades to a faint silhouette at times, the outlines of its form barely visible against its surroundings. Two malevolent eyes stare out from under its deeply hooded robe, each illuminated by an unholy crimson glow. Its thin, lanky arms end in unnaturally long taloned fingers, the semi-translucent claws still holding a twinge of glistening red on their surface. The creature is completely silent, its flickering form stalking with surprising speed and grace as it traverses the bog."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [
      "A bog spectre glows faintly as a spectral mist begins to swirl around {pronoun}."
    ],
    attacks: {
      attack: [
        "A bog spectre tries to ensnare you!",
        "A bog spectre waves a ghostly hand at you!"
      ],
      claw: [
        "A bog spectre claws at you!"
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
