{
  schema_version: 3,
  name: "wood wight",
  noun: "wight",
  url: "https://gswiki.play.net/wood_wight",
  picture: "",
  level: 20,
  family: "Wight",
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
  max_hp: 170,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Plains of Vornavis",
      uids: [4212201..4212222]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 156
      },
      {
        name: "Closed fist",
        as: 166
      },
      {
        name: "Pound",
        as: 146
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Mind Jolt (706)",
        cs: 123
      }
    ],
    offensive_spells: [
      {
        name: "Earthen Fury (917)"
      }
    ],
    maneuvers: [
      {
        name: "Gas cloud"
      },
      {
        name: "Gesture"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (69..177),
    ranged: (66..112),
    bolt: (66..112),
    udf: (92..180),
    bar_td: 66,
    cle_td: (60..66),
    emp_td: (52..60),
    pal_td: (57..66),
    ran_td: (54..60),
    sor_td: (61..67),
    wiz_td: nil,
    mje_td: (62..63),
    mne_td: (62..63),
    mjs_td: (54..72),
    mns_td: (54..72),
    mnm_td: (60..63),
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
    skin: "a wight scalp",
    other: "glimmering blue essence dust",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The wood wight stalks the forest, searching for decaying and not-so-decaying flesh. Perhaps once a powerful human ranger, the wood wight is still powerful, but its tattered clothing is covered with mold, fungus and moss. The wood wight shambles about, mercilessly attacking anything living. Its cold, grey eyes and clammy fingers wield magic and weaponry with equal skill."
    ],
    arrival: [
      "A wood wight just arrived.",
      "A wood wight just arrived, limping badly."
    ],
    flee: [
      "A wood wight runs {direction}.",
      "A wood wight limps {direction}."
    ],
    death: [
      "The wood wight screams evilly one last time and goes still."
    ],
    decay: [
      "A wood wight crumbles to dust."
    ],
    search: [],
    spell_prep: [
      "A wood wight chants an evil incantation."
    ],
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
