{
  schema_version: 3,
  name: "tomb wight",
  noun: "wight",
  url: "https://gswiki.play.net/tomb_wight",
  picture: "",
  level: 15,
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
  max_hp: 135,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "The Graveyard",
      uids: [18029..18035, 2162107..2162122]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Broadsword",
        as: (131..163)
      },
      {
        name: "Two-handed sword",
        as: 157
      },
      {
        name: "Twohanded sword",
        as: (127..157)
      },
      {
        name: "Blackened claidhmore",
        as: 141
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Twohanded sword",
        cs: 90
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Web"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "18",
    immunities: [],
    melee: (64..187),
    ranged: (7..119),
    bolt: (7..119),
    udf: (75..166),
    bar_td: 45,
    cle_td: (39..51),
    emp_td: (45..53),
    pal_td: (42..51),
    ran_td: (39..51),
    sor_td: 45,
    wiz_td: 45,
    mje_td: 45,
    mne_td: 45,
    mjs_td: (45..60),
    mns_td: (45..60),
    mnm_td: (42..51),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a broadsword",
    "a metal breastplate",
    "a twohanded sword",
    "a wooden shield",
    "an augmented breastplate"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a wight claw",
    other: [
      "s'ayanad crystal",
      "ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A tomb wight is a mass of blackened muscle in humanoid form. Striding boldly upright and with a determined gaze, a tomb wight marches through the world of the dead, seeking the bodies of the recently deceased. Though, in fact, dead itself, its putrid breath reveals its consumption of a steady diet of decayed flesh. If none can be found, a tomb wight is more than happy to cause the living to become the recently deceased."
    ],
    arrival: [
      "A tomb wight just arrived.",
      "A tomb wight just arrived, limping.",
      "A tomb wight just arrived, limping badly."
    ],
    flee: [
      "A tomb wight runs {direction}.",
      "A tomb wight limps {direction}."
    ],
    death: [
      "The tomb wight falls to the ground motionless.",
      "The tomb wight screams evilly one last time and goes still."
    ],
    decay: [
      "A tomb wight crumbles to dust."
    ],
    search: [],
    spell_prep: [
      "A tomb wight chants an evil incantation.",
      "A tomb wight's eyes flare with delight as {pronoun} eyes a blackened claidhmore."
    ],
    attacks: {
      attack: [
        "A tomb wight swings {weapon} at you!",
        "A tomb wight swings a twohanded sword at {target}!"
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
