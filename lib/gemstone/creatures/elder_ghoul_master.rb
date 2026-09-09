{
  schema_version: 3,
  name: "elder ghoul master",
  noun: "master",
  url: "https://gswiki.play.net/elder_ghoul_master",
  picture: "",
  level: 18,
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
  max_hp: 160,
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
        name: "Claidhmore",
        as: 128
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
    asg: "12",
    immunities: [],
    melee: 148,
    ranged: (33..59),
    bolt: (33..59),
    udf: 118,
    bar_td: nil,
    cle_td: 54,
    emp_td: 54,
    pal_td: nil,
    ran_td: 54,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 54,
    mne_td: 54,
    mjs_td: (45..54),
    mns_td: (45..54),
    mnm_td: 54,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a blackened claidhmore",
    "some blackened brigandine"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a ghoul master claw",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The elder ghoul master is a mass of blackened muscle in humanoid form. Striding boldly upright and with a determined gaze, the elder ghoul master marches through the world of the dead, seeking the bodies of the recently deceased. Though, in fact, dead itself, its putrid breath reveals its consumption of a steady diet of decayed flesh. If none can be found, the elder ghoul master is more than happy to cause the living to become the recently deceased."
    ],
    arrival: [
      "An elder ghoul master just arrived."
    ],
    flee: [],
    death: [
      "The elder ghoul master falls to the ground motionless.",
      "The elder ghoul master screams evilly one last time and goes still."
    ],
    decay: [
      "An elder ghoul master turns to dust.",
      "A small, green cloud of smelly gas rises from the body of a big ugly kobold as {pronoun} decays into compost."
    ],
    search: [],
    spell_prep: [
      "An elder ghoul master gestures and utters a phrase of magic!"
    ],
    attacks: {
      attack: [
        "An elder ghoul master swings {weapon} at you!"
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
