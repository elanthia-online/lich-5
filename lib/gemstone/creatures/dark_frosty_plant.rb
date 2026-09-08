{
  schema_version: 3,
  name: "dark frosty plant",
  noun: "plant",
  url: "https://gswiki.play.net/dark_frosty_plant",
  picture: "",
  level: 45,
  family: "Plant",
  type: "Plantlife",
  undead: true,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "corporeal undead"
  ],
  bcs: true,
  max_hp: 400,
  speed: (3..6),
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Abandoned Farm",
      uids: [4124050..4124062]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "ranged: frosty seed",
        as: 260
      },
      {
        name: "Frost-covered crystalline flower",
        as: (138..260)
      },
      {
        name: "melee: stab",
        as: 260
      },
      {
        name: "Stinger",
        as: 242
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Point"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (83..259),
    ranged: (119..143),
    bolt: (119..143),
    udf: (203..375),
    bar_td: nil,
    cle_td: (183..186),
    emp_td: (180..186),
    pal_td: (155..158),
    ran_td: (158..167),
    sor_td: (186..195),
    wiz_td: nil,
    mje_td: 201,
    mne_td: 201,
    mjs_td: (177..186),
    mns_td: (177..186),
    mnm_td: (135..144),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "frosted branch",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Though this plant with its droopy leafs and sickly flowers is a bit on the far gone side, it might still benefit from being re-potted. Preferably six feet under!"
    ],
    arrival: [
      "A dark frosty plant stalks in and plants its roots."
    ],
    flee: [
      "A dark frosty plant stalks {direction}."
    ],
    death: [
      "A dark frosty plant collapses to the ground, twitches one last time and dies."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A dark frosty plant flings a frost-covered crystalline flower towards you!",
        "A dark frosty plant rotates until it points a large flower at you!",
        "A dark frosty plant stabs at you with {pronoun} stinger!",
        "A dark frosty plant turns one of {pronoun} massive flowers towards you and spits a seed in your direction!",
        "A dark frosty plant stabs at {target} with {pronoun} stinger!"
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
