{
  schema_version: 3,
  name: "shelfae guard",
  noun: "guard",
  url: "https://gswiki.play.net/shelfae_guard",
  picture: "",
  level: 7,
  family: "Shelfae",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 100,
  speed: 7,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Cliffwalk",
      uids: [7129001..7129017]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 82
      },
      {
        name: "Claw",
        as: 82
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
    asg: nil,
    immunities: [],
    melee: (11..21),
    ranged: 10,
    bolt: 10,
    udf: (49..55),
    bar_td: nil,
    cle_td: 21,
    emp_td: 21,
    pal_td: (18..21),
    ran_td: 21,
    sor_td: 21,
    wiz_td: nil,
    mje_td: 21,
    mne_td: 21,
    mjs_td: (30..33),
    mns_td: (30..33),
    mnm_td: 21,
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
    skin: "scale",
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      ""
    ],
    arrival: [
      "A shelfae guard just arrived."
    ],
    flee: [
      "A shelfae guard runs {direction}."
    ],
    death: [
      "The shelfae guard falls to the ground and dies.",
      "The shelfae guard screams one last time and dies."
    ],
    decay: [
      "A guard crumbles into dust."
    ],
    search: [],
    spell_prep: [],
    stand: [
      "A shelfae guard stands back up with a sibilant hiss."
    ],
    attacks: {
      claw: [
        "A shelfae guard claws at you!"
      ],
      bite: [
        "A shelfae guard tries to bite you!"
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
