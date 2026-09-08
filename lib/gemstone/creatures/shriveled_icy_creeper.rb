{
  schema_version: 3,
  name: "shriveled icy creeper",
  noun: "creeper",
  url: "https://gswiki.play.net/shriveled_icy_creeper",
  picture: "",
  level: 50,
  family: "Creeper",
  type: "Plantlife",
  undead: true,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "corporeal undead"
  ],
  bcs: true,
  max_hp: 450,
  speed: 7,
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
        name: "melee: stab",
        as: 285
      },
      {
        name: "Stinger",
        as: 289
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "creeper vine"
      },
      {
        name: "leafy appendages"
      },
      {
        name: "Vine Fling"
      },
      {
        name: "Whip"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (153..356),
    ranged: (128..193),
    bolt: (128..193),
    udf: (182..317),
    bar_td: nil,
    cle_td: (185..191),
    emp_td: (183..192),
    pal_td: (153..156),
    ran_td: (147..156),
    sor_td: (194..203),
    wiz_td: nil,
    mje_td: (204..205),
    mne_td: (204..205),
    mjs_td: (183..192),
    mns_td: (183..192),
    mnm_td: (150..153),
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
    skin: "shriveled cutting",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Looking nearly to expire, this creeper definitely falls into the unhealthy category but don't let looks fool you. If you or a friend falls into it, it is likely that you or they will fall into an unhealthy ... or dead category too!"
    ],
    arrival: [],
    flee: [
      "A shriveled icy creeper creeps {direction}."
    ],
    death: [
      "A shriveled icy creeper collapses to the ground, twitches one last time and dies.",
      "A shriveled icy creeper twitches one last time and dies."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A shriveled icy creeper stabs at you with {pronoun} stinger!",
        "A shriveled icy creeper stabs at {target} with {pronoun} stinger!",
        "A shriveled icy creeper flings a length of creeper vine towards you, but with a flash of incredible reflexes, you skip out of the way and the creeper vine, trailing the rest of {pronoun} body, lands sprawling on the ground."
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
