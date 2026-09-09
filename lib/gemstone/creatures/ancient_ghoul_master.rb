{
  schema_version: 3,
  name: "ancient ghoul master",
  noun: "master",
  url: "https://gswiki.play.net/ancient_ghoul_master",
  picture: "",
  level: 21,
  family: "Ghoul",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: nil,
  muggable: false,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 180,
  speed: 7,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "The Graveyard",
      uids: [18029..18035, 18070..18070]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Battle axe",
        as: 147
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Torment (718)",
        cs: 127
      }
    ],
    offensive_spells: [],
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
    asg: "20",
    immunities: [],
    melee: (28..108),
    ranged: (23..54),
    bolt: (23..54),
    udf: nil,
    bar_td: nil,
    cle_td: 63,
    emp_td: 63,
    pal_td: nil,
    ran_td: 63,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 63,
    mne_td: 63,
    mjs_td: 63,
    mns_td: 63,
    mnm_td: 63,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a blackened battle axe",
    "some blackened platemail"
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
      "The ancient ghoul master is a mass of blackened muscle in humanoid form. Striding boldly upright and with a determined gaze, the ancient ghoul master marches through the world of the dead, seeking the bodies of the recently deceased. Though, in fact, dead itself, its putrid breath reveals its consumption of a steady diet of decayed flesh. If none can be found, the ancient ghoul master is more than happy to cause the living to become the recently deceased."
    ],
    arrival: [
      "An ancient ghoul master just arrived."
    ],
    flee: [],
    death: [
      "The ancient ghoul master falls to the ground motionless.",
      "The ancient ghoul master screams evilly one last time and goes still."
    ],
    decay: [
      "An ancient ghoul master turns to dust."
    ],
    search: [],
    spell_prep: [
      "An ancient ghoul master chants an evil incantation!"
    ],
    attacks: {
      attack: [
        "An ancient ghoul master swings {weapon} at you!"
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
