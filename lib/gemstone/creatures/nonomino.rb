{
  schema_version: 3,
  name: "nonomino",
  noun: "nonomino",
  url: "https://gswiki.play.net/nonomino",
  picture: "",
  level: 23,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 194,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Castle Anwyn",
      uids: [4285010..4285022, 4285030..4285050]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ball and chain",
        as: 160
      },
      {
        name: "Dagger",
        as: (147..160)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Blind (311)",
        cs: 139
      },
      {
        name: "Point",
        cs: 139
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [],
    melee: (155..253),
    ranged: (164..253),
    bolt: (164..253),
    udf: (183..241),
    bar_td: 74,
    cle_td: (92..98),
    emp_td: (84..94),
    pal_td: (75..81),
    ran_td: (71..81),
    sor_td: (88..95),
    wiz_td: nil,
    mje_td: (85..98),
    mne_td: (85..98),
    mjs_td: (94..100),
    mns_td: (94..100),
    mnm_td: (80..87),
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Warding II (107)",
      "Prayer of Protection (303)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a corroded steel dagger",
    "a rotting wooden shield",
    "a wickedly spiked ball & chain",
    "some tattered leathers"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "glimmering blue essence dust",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A creature of sublime beauty, the nonomino floats just above the ground in a pulsing sphere of unearthly light. As you watch, he abruptly turns his head to stare, as cracks distend across his visage and the glorious mantle peels away to reveal disease and decay. The incarnation constantly molts his epidermis, regenerating it moments later in a hideous parody of the struggle between life and death. Frozen by the hypnotic horror of his appearance, you almost fail to notice the nonomino's fluid movement, and the adept dance of his hands as he summons his theurgical arsenal."
    ],
    arrival: [
      "A nonomino shambles in!",
      "A nonomino just came through an arched door leading into the old Castle Keep."
    ],
    flee: [
      "A nonomino shambles {direction}.",
      "A nonomino wails madly as he limps {direction}.",
      "A nonomino just went through an arched door leading into the old Castle Keep."
    ],
    death: [
      "The nonomino falls to the ground motionless.",
      "The nonomino wails in terrifying pain one last time and lies still."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A nonomino swings {weapon} at you!"
      ],
      cast: [
        "A nonomino points a rotting finger at {target}!"
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
