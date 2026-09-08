{
  schema_version: 3,
  name: "shelfae assailant",
  noun: "assailant",
  url: "https://gswiki.play.net/shelfae_assailant",
  picture: "",
  level: nil,
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
  max_hp: 138,
  speed: 7,
  height: 7,
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
        as: 110
      },
      {
        name: "Claw",
        as: 120
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
    melee: (19..25),
    ranged: 6,
    bolt: 6,
    udf: (65..73),
    bar_td: nil,
    cle_td: 33,
    emp_td: (9..37),
    pal_td: (30..33),
    ran_td: 33,
    sor_td: 33,
    wiz_td: nil,
    mje_td: 33,
    mne_td: 33,
    mjs_td: 33,
    mns_td: 33,
    mnm_td: 33,
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
    skin: "crest",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      ""
    ],
    arrival: [
      "A shelfae assailant just arrived."
    ],
    flee: [
      "A shelfae assailant runs {direction}.",
      "A shelfae assailant limps {direction}."
    ],
    death: [
      "The shelfae assailant falls to the ground and dies.",
      "The shelfae assailant screams one last time and dies."
    ],
    decay: [
      "An assailant crumbles into dust."
    ],
    search: [],
    spell_prep: [],
    stand: [
      "A shelfae assailant stands back up with a sibilant hiss."
    ],
    attacks: {
      claw: [
        "A shelfae assailant claws at you!"
      ],
      bite: [
        "A shelfae assailant tries to bite you!"
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
