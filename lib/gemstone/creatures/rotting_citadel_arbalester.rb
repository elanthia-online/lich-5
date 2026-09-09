{
  schema_version: 3,
  name: "rotting citadel arbalester",
  noun: "arbalester",
  url: "https://gswiki.play.net/rotting_citadel_arbalester",
  picture: "",
  level: 58,
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
  max_hp: 300,
  speed: 6,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "The Citadel",
      uids: [377013..377015, 377027..377030, 377320..377344]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Heavy crossbow",
        as: 312
      },
      {
        name: "Wooden burning bolt",
        as: 312
      },
      {
        name: "Wooden heavy crossbow bolt",
        as: 318
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Sweep"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: (230..466),
    ranged: (227..300),
    bolt: (227..300),
    udf: 486,
    bar_td: 185,
    cle_td: (196..205),
    emp_td: (202..211),
    pal_td: (183..186),
    ran_td: (177..186),
    sor_td: (206..224),
    wiz_td: nil,
    mje_td: (220..408),
    mne_td: (220..408),
    mjs_td: 282,
    mns_td: 282,
    mnm_td: (174..183),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a dusty black oak and steel arbalest",
    "some rotting buff and blue brigandine"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "inky necrotic core",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A rusted conical helmet, wrapped in a band of buff and blue, sits above the empty eye sockets of a skull draped in the rotting remains of a rotting Citadel arbalester's face. Residual juices drip from the head of the arbalester and down a ragged surcoat of buff and blue cinched with a tattered leather belt buckled with a rusted shield stamped with a large letter \"E.\" A quiver hangs from the belt, flush with feathered bolts and within easy reach of the arbalester's gloved hands."
    ],
    arrival: [
      "A rotting Citadel arbalester strides into the room, {pronoun} crossbow cradled in the crook of an arm.",
      "A rotting Citadel arbalester strides in.",
      "A rotting Citadel arbalester strides into the area, {pronoun} crossbow cradled in the crook of an arm."
    ],
    flee: [
      "A rotting Citadel arbalester strides {direction}."
    ],
    death: [
      "A rotting Citadel arbalester collapses motionless to the floor.",
      "A rotting Citadel arbalester collapses motionless to the ground.",
      "A putrefied Citadel herald collapses in upon {pronoun}, leaving behind a pile of dust."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      fire: [
        "A rotting Citadel arbalester fires {weapon} at you!",
        "A rotting citadel arbalester fires a wooden heavy crossbow bolt at you!",
        "A rotting citadel arbalester fires a wooden burning bolt at you!"
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
