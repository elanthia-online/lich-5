{
  schema_version: 3,
  name: "phantom",
  noun: "phantom",
  url: "https://gswiki.play.net/phantom",
  picture: "",
  level: 2,
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
  max_hp: 43,
  speed: 8,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "The Graveyard",
      uids: [18008..18011, 18013..18028, 2162201..2162211]
    },
    {
      name: "Southern Snowfields",
      uids: [4128058..4128070]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 28
      },
      {
        name: "Dagger",
        as: 0
      }
    ],
    bolt_spells: [
      {
        name: "Minor Shock (901)",
        as: 35
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "5",
    immunities: [],
    melee: (-36..6),
    ranged: (-29..-6),
    bolt: (-29..-6),
    udf: 25,
    bar_td: 6,
    cle_td: 6,
    emp_td: 6,
    pal_td: (3..6),
    ran_td: 6,
    sor_td: 6,
    wiz_td: 6,
    mje_td: 6,
    mne_td: 6,
    mjs_td: (6..15),
    mns_td: (6..15),
    mnm_td: 6,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a woven cloak",
    "some double leather"
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
      "Barely still connected to the living plane, the phantom flickers in and out as it confronts those that would intrude upon its rest. The outlines of its shape are barely apparent, suggesting a once-humanoid appearance, now disguised in a transparent, flickering whiteness. The phantom must move and strike quickly, as it is only able to glimpse the figures of the targets around it when the phantom is at its most visible state."
    ],
    arrival: [
      "Out of thin air, a shadowy figure takes shape before your eyes and materializes into a phantom!",
      "A phantom just arrived."
    ],
    flee: [],
    death: [
      "The phantom slowly settles to the ground and begins to dissipate."
    ],
    decay: [
      "A phantom vanishes into thin air, leaving no trace behind."
    ],
    search: [],
    spell_prep: [
      "A phantom begins to moan an incantation!"
    ],
    attacks: {
      attack: [
        "A phantom gestures at you!",
        "A phantom swings {weapon} at you!"
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
