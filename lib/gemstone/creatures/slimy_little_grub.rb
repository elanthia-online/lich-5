{
  schema_version: 3,
  name: "slimy little grub",
  noun: "grub",
  url: "https://gswiki.play.net/slimy_little_grub",
  picture: "",
  level: 1,
  family: "Worm",
  type: "Worm",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 28,
  speed: nil,
  height: 1,
  size: "tiny",
  areas: [
    {
      name: "Wehntoph",
      uids: [484001..484013]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Stinger (attack)",
        as: 47
      },
      {
        name: "Stinger",
        as: 37
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (25..81),
    ranged: (13..26),
    bolt: (13..26),
    udf: (37..93),
    bar_td: 3,
    cle_td: 3,
    emp_td: 3,
    pal_td: 3,
    ran_td: 3,
    sor_td: 3,
    wiz_td: nil,
    mje_td: 3,
    mne_td: 3,
    mjs_td: 3,
    mns_td: 3,
    mnm_td: 3,
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
    coins: true,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The little grub is a small yellowish white creature little more than six inches long. It is covered in a sickly green slime that leaves a trail behind it."
    ],
    arrival: [
      "A slimy little grub crawls in, leaving a trail of slime in its wake."
    ],
    flee: [
      "A slimy little grub slithers {direction}."
    ],
    death: [
      "The grub rolls over and dies."
    ],
    decay: [
      "A slimy little grub decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A little grub stabs at you with {pronoun} stinger!",
        "A slimy little grub stabs at {target} with {pronoun} stinger!"
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
