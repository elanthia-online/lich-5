{
  schema_version: 3,
  name: "decaying citadel guardsman",
  noun: "guardsman",
  url: "https://gswiki.play.net/decaying_citadel_guardsman",
  picture: "",
  level: 56,
  family: "Humanoid",
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
    "corporeal undead"
  ],
  bcs: true,
  max_hp: 300,
  speed: 8,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "The Citadel",
      uids: [377002..377008, 377013..377015, 377020..377030, 377301..377314, 377320..377344]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Hammer of Kai",
        as: 327
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Charge"
      },
      {
        name: "Trip"
      },
      {
        name: "Polearm Plant"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16",
    immunities: [],
    melee: (197..436),
    ranged: (181..292),
    bolt: (181..292),
    udf: (288..469),
    bar_td: 168,
    cle_td: (183..192),
    emp_td: (184..193),
    pal_td: (168..197),
    ran_td: (177..180),
    sor_td: (188..197),
    wiz_td: nil,
    mje_td: (216..218),
    mne_td: (216..218),
    mjs_td: (181..187),
    mns_td: (181..187),
    mnm_td: (168..177),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a tarnished and rusted Hammer of Kai",
    "some faded buff and blue hauberk"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "inky necrotic core",
    armaments: [
      "polished red steel Hammer of Kai"
    ],
    transmogs: nil
  },
  messaging: {
    description: [
      "Blazing white balefire fills the eye sockets of the Citadel guardsman, who is dressed in the deteriorating remains of a once resplendent uniform of buff and blue. The taut, sinewy flesh stretched over the guardsman's exposed face and hands is riddled with gaping holes that reveal the desiccated remains of muscle and cartilage. Gripped firmly in hands of exposed bone and flesh is an immaculate Hammer of Kai, which is aflame in a radiant white fire that burns along its blade."
    ],
    arrival: [
      "A decaying Citadel guardsman strides in.",
      "A rotting Citadel arbalester strides into the room, her crossbow cradled in the crook of an arm.",
      "A decaying Citadel guardsman marches into the room shouting, \"The Citadel will not fall, you krolvin scum!\"",
      "A decaying Citadel guardsman marches into the room shouting, \"The Citadel will not fall, you troll scum!\"",
      "A decaying Citadel guardsman marches into the area shouting, \"The Citadel will not fall, you troll scum!\"",
      "A decaying Citadel guardsman marches into the area shouting, \"The Citadel will not fall, you krolvin scum!\""
    ],
    flee: [],
    death: [
      "A decaying Citadel guardsman collapses sobbing silently before lying motionless on the floor.",
      "A decaying Citadel guardsman collapses sobbing silently before lying motionless on the ground.",
      "A putrefied Citadel herald collapses in upon {pronoun}, leaving behind a pile of dust.",
      "A decaying Citadel guardsman collapses sobbing, \"...the Citadel has fallen,\" before lying motionless and silent on the floor."
    ],
    decay: [
      "The body of a decaying Citadel guardsman collapses into a pile of dust which blows away in an errant draft.",
      "The body of a decaying Citadel guardsman collapses into a pile of dust which blows away in an errant breeze."
    ],
    search: [],
    spell_prep: [
      "A decaying citadel guardsman kneels and murmurs a short prayer before rising back to {pronoun} feet."
    ],
    stun_break: [
      "A decaying citadel guardsman stumbles about trying to regain {pronoun} bearings!"
    ],
    attacks: {
      attack: [
        "A decaying Citadel guardsman swings {weapon} at you!",
        "A decaying Citadel guardsman thrusts with a rhimar trident at you!",
        "A decaying citadel guardsman thrusts with a rhimar trident at you!"
      ],
      charge: [
        "A decaying Citadel guardsman rushes forward at you with {pronoun} rusted Hammer of Kai and attempts a charge!",
        "A decaying Citadel guardsman rushes forward at you with {pronoun} red steel Hammer of Kai and attempts a charge!",
        "A decaying citadel guardsman rushes forward at you with {pronoun} {weapon} and attempts a charge!"
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
