{
  schema_version: 3,
  name: "dark apparition",
  noun: "apparition",
  url: "https://gswiki.play.net/dark_apparition",
  picture: "",
  level: 5,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 65,
  speed: 8,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Glaise Cnoc Cemetery",
      uids: [14008073..14008081]
    },
    {
      name: "Southern Snowfields",
      uids: [4128058..4128070]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 48
      },
      {
        name: "Claw",
        as: 58
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Blood Burst (701)",
        cs: 46
      },
      {
        name: "Mana Disruption (702)",
        cs: 46
      },
      {
        name: "Bite",
        cs: 46
      },
      {
        name: "Claw",
        cs: 46
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (-15..54),
    ranged: (-21..-10),
    bolt: (-21..-10),
    udf: (1..59),
    bar_td: 15,
    cle_td: 15,
    emp_td: 15,
    pal_td: (12..15),
    ran_td: 15,
    sor_td: 15,
    wiz_td: 15,
    mje_td: 15,
    mne_td: 15,
    mjs_td: 15,
    mns_td: 15,
    mnm_td: 15,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye"
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
      "It is difficult to focus on the shape of the dark apparition. It wavers and shifts as an image seen through dark waters yet each shape it assumes has some aspect of horror and bloody death. One form is that of a corpse mutilated beyond words with arms hacked to stumps yet tipped with shining claws. Another is that of a waif horribly burned and scarred so that her features run like melted wax. Yet another is something apparently torn apart by huge razors...flesh hanging in sheets that blow in some ill-spawned breeze like leaves of sea-grass in the current. The sight would make any normal person turn and gag, being unable to bear any more."
    ],
    arrival: [
      "Out of thin air, a shadowy figure takes shape before your eyes and materializes into a dark apparition!",
      "A dark apparition just arrived."
    ],
    flee: [],
    death: [
      "The dark apparition slowly settles to the ground and begins to dissipate."
    ],
    decay: [
      "A dark apparition vanishes into thin air, leaving no trace behind."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      claw: [
        "A dark apparition claws at you!"
      ],
      bite: [
        "A dark apparition tries to bite you!"
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
