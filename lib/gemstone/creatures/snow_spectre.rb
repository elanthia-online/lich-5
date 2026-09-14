{
  schema_version: 3,
  name: "snow spectre",
  noun: "spectre",
  url: "https://gswiki.play.net/snow_spectre",
  picture: "",
  level: 9,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
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
  max_hp: 91,
  speed: 5,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "High Plains",
      uids: [4129100..4129110]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 98
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Fear",
        cs: (47..53)
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
    melee: (2..35),
    ranged: (-14..0),
    bolt: (-14..0),
    udf: 24,
    bar_td: 27,
    cle_td: 27,
    emp_td: 27,
    pal_td: (24..27),
    ran_td: 27,
    sor_td: 27,
    wiz_td: nil,
    mje_td: 27,
    mne_td: 27,
    mjs_td: 27,
    mns_td: 27,
    mnm_td: 27,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a leather helm",
    "a woven cloak"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a spectre nail",
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The snow spectre floats easily over the ground, seeming to move through solid obstacles with little effort. Its appearance alternates between a flickering, semi-transparent apparition and a near-blinding, white, icy solidity. Its face is permanently twisted into a tortured, leering grin and its eyes stare far ahead, as if transfixed on something horrible in the distance."
    ],
    arrival: [
      "A snow spectre just arrived."
    ],
    flee: [],
    death: [
      "The snow spectre falls to the ground motionless.",
      "The snow spectre screams evilly one last time and goes still."
    ],
    decay: [
      "A snow spectre turns to dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A snow spectre swings {weapon} at you!"
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
