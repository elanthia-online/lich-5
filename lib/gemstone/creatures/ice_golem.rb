{
  schema_version: 3,
  name: "ice golem",
  noun: "golem",
  url: "https://gswiki.play.net/ice_golem",
  picture: "",
  level: 53,
  family: "Golem",
  type: "Biped",
  undead: false,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: false,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Magical",
    "Element-based"
  ],
  bcs: true,
  max_hp: 500,
  speed: nil,
  height: 21,
  size: "huge",
  areas: [
    {
      name: "Great Mountain Aenatumgana",
      uids: [4561102..4561141]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound"
      },
      {
        name: "Stomp",
        as: 319
      },
      {
        name: "Ensnare",
        as: 333
      },
      {
        name: "Fist",
        as: (327..335)
      },
      {
        name: "Foot",
        as: (265..333)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Tremors (909)"
      }
    ],
    maneuvers: [
      {
        name: "Ground Slam"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (154..233),
    ranged: (160..234),
    bolt: (160..234),
    udf: (266..274),
    bar_td: nil,
    cle_td: (203..209),
    emp_td: 207,
    pal_td: (173..179),
    ran_td: 167,
    sor_td: 207,
    wiz_td: nil,
    mje_td: (210..219),
    mne_td: (210..219),
    mjs_td: (195..211),
    mns_td: (195..211),
    mnm_td: 159,
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
    skin: nil,
    other: "crystal core",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The ice golem is a mammoth construct of freezing cold ice and snow. Towering over twenty feet in height, this ice golem surely weighs several tons. The ice golem's rime-covered face displays its sharp, angular features, over which whisps from its frosty brow droop."
    ],
    arrival: [
      "An ice golem lumbers in, followed by a hailing icestorm!",
      "An ice golem slowly lumbers in, followed by a hailing icestorm!"
    ],
    flee: [
      "An ice golem lumbers {direction}, followed by a hailing icestorm.",
      "An ice golem heads {direction}, dragging your battered body behind {pronoun}!"
    ],
    death: [
      "The ice golem writhes in cold agony and dies.",
      "An ice golem topples heavily to the ground!",
      "The ice golem falls to the ground dead, {pronoun} husk still pulsating with a blinding white hue."
    ],
    decay: [],
    search: [
      "An ice golem looks around apprehensively as {pronoun} starts to melt!"
    ],
    spell_prep: [],
    stun_break: [
      "The ice golem shrugs off the blow, then the living ice that the ice golem is made of reforms {pronoun} missing left arm!",
      "The ice golem shrugs off the blow, then the living ice that the ice golem is made of reforms {pronoun} missing right arm!",
      "The ice golem shrugs off the blow, then the living ice that the ice golem is made of reforms {pronoun} missing left hand!"
    ],
    attacks: {
      attack: [
        "An ice golem pounds at you with {pronoun} fist!",
        "An ice golem stomps at you with {pronoun} foot!",
        "An ice golem tries to ensnare you!"
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
