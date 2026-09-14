{
  schema_version: 3,
  name: "moaning phantom",
  noun: "phantom",
  url: "https://gswiki.play.net/moaning_phantom",
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
  max_hp: 44,
  speed: 8,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "Glaise Cnoc Cemetery",
      uids: [14008011..14008025]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 28
      },
      {
        name: "Unknown",
        as: 28
      }
    ],
    bolt_spells: [
      {
        name: "Minor Shock (901)",
        as: 50
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: -26,
    ranged: -28,
    bolt: -28,
    udf: 1,
    bar_td: 6,
    cle_td: 6,
    emp_td: 6,
    pal_td: (3..6),
    ran_td: 6,
    sor_td: 6,
    wiz_td: 6,
    mje_td: 6,
    mne_td: 6,
    mjs_td: 6,
    mns_td: 6,
    mnm_td: 6,
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
      "Barely still connected to the living plane, the moaning phantom flickers in and out as it confronts those that would intrude upon its rest. The outlines of its shape are barely apparent, but what is visible suggests a once-humanoid appearance, caught in a continuous scream of anguish. The phantom must move and strike quickly, as it is only able to glimpse the figures of the targets around it when it is in its most visible state."
    ],
    arrival: [
      "A darkness flows out of the ground and materializes into a moaning phantom!",
      "A moaning phantom just arrived."
    ],
    flee: [],
    death: [
      "The moaning phantom slowly settles to the ground and begins to dissipate."
    ],
    decay: [
      "A moaning phantom vanishes into thin air, leaving no trace behind."
    ],
    search: [],
    spell_prep: [
      "A moaning phantom begins to moan an incantation!"
    ],
    attacks: {
      attack: [
        "A moaning phantom swings {weapon} at you!",
        "A moaning phantom gestures at you!"
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
