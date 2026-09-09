{
  schema_version: 3,
  name: "firephantom",
  noun: "firephantom",
  url: "https://gswiki.play.net/firephantom",
  picture: "",
  level: 6,
  family: "Elemental",
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
    "Non-corporeal undead",
    "Element-based"
  ],
  bcs: nil,
  max_hp: 73,
  speed: 6,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Glatoph",
      uids: [35010..35024]
    },
    {
      name: "Vornavian Coast",
      uids: [4202301..4202320]
    },
    {
      name: "The Citadel",
      uids: [2102001..2102006, 2102059..2102069]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 77
      }
    ],
    bolt_spells: [
      {
        name: "Minor Fire (906)",
        as: 69
      },
      {
        name: "Major Fire (908)",
        as: 69
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
    melee: (-69..7),
    ranged: (-75..-61),
    bolt: (-75..-61),
    udf: (1..13),
    bar_td: 18,
    cle_td: 18,
    emp_td: 18,
    pal_td: (15..18),
    ran_td: 18,
    sor_td: 18,
    wiz_td: nil,
    mje_td: 18,
    mne_td: 18,
    mjs_td: 48,
    mns_td: 48,
    mnm_td: 18,
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
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A billowing pillar of searing fire, the firephantom darts about quickly to set aflame any that would stand in its way. Although it has a vaguely humanoid appearance, its form is entirely composed of fire, with the legs a dark red. The darker red slowly gives way to blazing red in the torso and bright yellow in the cranial area. Where the eyes and mouth should be only empty holes exist, floating eerily in the head of this mobile conflagration."
    ],
    arrival: [
      "A firephantom just arrived."
    ],
    flee: [],
    death: [
      "The firephantom slowly settles to the ground and begins to dissipate."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A firephantom swings {weapon} at you!",
        "A firephantom gestures at you!"
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
