{
  schema_version: 3,
  name: "ash guardian",
  noun: "guardian",
  url: "https://gswiki.play.net/ash_guardian",
  picture: "",
  level: 87,
  family: "elemental",
  type: "Biped",
  undead: false,
  blood: false,
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
    "Element-based"
  ],
  bcs: true,
  max_hp: 238,
  speed: 4,
  height: 8,
  size: "medium",
  areas: [
    {
      name: "Volcanic Flats",
      uids: [3023107..3023123]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Falchion",
        as: 402
      },
      {
        name: "Ensnare",
        as: 346
      },
      {
        name: "Jagged shard of obsidian",
        as: 406
      },
      {
        name: "Sharp beak",
        as: 295
      },
      {
        name: "Beak",
        as: 375
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Feint"
      },
      {
        name: "Dirtkick"
      },
      {
        name: "Shield Bash"
      },
      {
        name: "Dust Kick"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16N",
    immunities: [],
    melee: (212..494),
    ranged: (156..431),
    bolt: (156..431),
    udf: (410..616),
    bar_td: nil,
    cle_td: 354,
    emp_td: (336..342),
    pal_td: (290..299),
    ran_td: (293..299),
    sor_td: (370..397),
    wiz_td: nil,
    mje_td: 390,
    mne_td: 390,
    mjs_td: (327..336),
    mns_td: (327..336),
    mnm_td: (261..264),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "Guards any phoenix killed in the room as it attempts its rebirth",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a jagged shard of obsidian",
    "a smoldering slab of glaes"
  ],
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
      "Distinct features are difficult to determine as clouds of ash obscure the form of the ash guardian. What is visible is a towering humanoid shadow that drifts through the ash clouds."
    ],
    arrival: [],
    flee: [
      "An ash guardian heads southwest in a roiling cloud of ash.",
      "An ash guardian heads northeast in a roiling cloud of ash.",
      "An ash guardian heads east in a roiling cloud of ash.",
      "An ash guardian heads west in a roiling cloud of ash.",
      "An ash guardian heads south in a roiling cloud of ash.",
      "An ash guardian heads southeast in a roiling cloud of ash.",
      "An ash guardian heads north in a roiling cloud of ash.",
      "An ash guardian heads northwest in a roiling cloud of ash."
    ],
    death: [
      "Ash explodes in all directions as an ash guardian succumbs to its final blow."
    ],
    decay: [
      "The form of an ash guardian dissolves into the surroundings."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "An ash guardian swings {weapon} at you!",
        "An ash guardian tries to ensnare you!",
        "An ash guardian attempts to kick dust at you, but is unable to kick up a sufficient amount of dust.",
        "An ash guardian lashes at you with a mediocre shield bash!",
        "An ash guardian manages to kick a large clump of dust at you!"
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
