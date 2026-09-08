{
  schema_version: 3,
  name: "winged viper",
  noun: "viper",
  url: "https://gswiki.play.net/winged_viper",
  picture: "",
  level: 60,
  family: "Reptilian",
  type: "Avian",
  undead: false,
  blood: nil,
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
  max_hp: 260,
  speed: nil,
  height: nil,
  size: "small",
  areas: [
    {
      name: "Red Forest",
      uids: [480201..480215, 17006201..17006215]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 294
      },
      {
        name: "Swoop",
        as: 298
      }
    ],
    bolt_spells: [
      {
        name: "Major Cold (907)"
      },
      {
        name: "Major Fire (908)"
      },
      {
        name: "Major Shock (910)"
      }
    ],
    warding_spells: [
      {
        name: "Elemental Strike (415)"
      },
      {
        name: "Bite",
        cs: 274
      }
    ],
    offensive_spells: [
      {
        name: "Call Swarm (615)"
      },
      {
        name: "Elemental Dispel (417)"
      },
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Major Elemental Wave (435)"
      },
      {
        name: "Sounds (607)"
      }
    ],
    maneuvers: [
      {
        name: "Spit"
      },
      {
        name: "Tongue Flick"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (166..245),
    ranged: (182..212),
    bolt: (182..212),
    udf: 244,
    bar_td: nil,
    cle_td: (221..225),
    emp_td: (225..234),
    pal_td: (188..191),
    ran_td: 191,
    sor_td: (231..241),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 247,
    mjs_td: nil,
    mns_td: 222,
    mnm_td: (192..201),
    defensive_spells: [
      "Elemental Barrier (430)",
      "Elemental Defense III (414)"
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
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "pure white feather",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The viper has a sinuous scaley body of purest white, feathered from snout to tail. Two majestic wings arch from its body roughly one-third of the way down its length. The viper's mouth is filled with long, needle sharp fangs, and its forked tongue flickers constantly to taste the air hungrily."
    ],
    arrival: [],
    flee: [
      "A winged viper flies {direction}."
    ],
    death: [
      "The winged viper crashes to the ground, motionless.",
      "The winged viper dissolves as the acidic poison consumes it from within."
    ],
    decay: [
      "The winged viper dissolves as the acidic poison consumes it from within."
    ],
    search: [
      "A winged viper looks around, eyes glowing softly as {pronoun} scour the surroundings."
    ],
    spell_prep: [
      "A winged viper hisses an arcane phrase in an unfamiliar sibilant language.",
      "A winged viper hisses loudly and soars higher in the air."
    ],
    attacks: {
      attack: [
        "A winged viper flips {pronoun} body around, flicking {pronoun} tongue at you!"
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
