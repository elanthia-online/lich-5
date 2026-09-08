{
  schema_version: 3,
  name: "flesh golem",
  noun: "golem",
  url: "https://gswiki.play.net/flesh_golem",
  picture: "",
  level: 50,
  family: "golem",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: false,
  sympathy: false,
  muggable: true,
  sleepable: false,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Corporeal undead",
    "Magical",
    "Boss"
  ],
  bcs: true,
  max_hp: 400,
  speed: 10,
  height: 9,
  size: "large",
  areas: [
    {
      name: "Marsh Keep",
      uids: [376051..376054, 376057..376088]
    },
    {
      name: "unmapped",
      uids: [376055..376056]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound (double attack)",
        as: 300
      },
      {
        name: "Stomp",
        as: 300
      },
      {
        name: "Fist",
        as: (230..304)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Noxious Cloud"
      },
      {
        name: "Twin Hammerfists"
      },
      {
        name: "Ground Slam"
      },
      {
        name: "Miasma"
      },
      {
        name: "Shield Bash"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (87..341),
    ranged: (125..241),
    bolt: (125..241),
    udf: (218..442),
    bar_td: 169,
    cle_td: (185..194),
    emp_td: (183..213),
    pal_td: (156..165),
    ran_td: (156..159),
    sor_td: (194..203),
    wiz_td: nil,
    mje_td: (183..211),
    mne_td: (183..211),
    mjs_td: (183..248),
    mns_td: (183..248),
    mnm_td: (150..159),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a pitted wooden shield covered in rusty black iron spikes",
    "a bruised left eye",
    "a bruised right eye",
    "a possible mild concussion"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "crystal core",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Overlapping layers of skin are stitched together in a patchwork pattern over a frame of bone to resemble the form of a man. Dark creases in the flesh offer the only indication of features in the golem's face, while the rest of its body is composed of blubbery mass and the occasional portion of some humanoid race, from kobold to krolvin. Two lengthy, thick arms that end in huge swollen fists distract from the great height of the golem."
    ],
    arrival: [
      "A flesh golem arrives with a trail of rotting skin behind it.",
      "A flesh golem ambles in while adjusting a piece of hanging skin."
    ],
    flee: [],
    death: [
      "A flesh golem collapses in a heap, {pronoun} huge girth shaking the floor around {pronoun}.",
      "A flesh golem collapses in a heap, {pronoun} huge girth shaking the ground around {pronoun}.",
      "The flesh golem falls to the floor dead, {pronoun} husk still pulsating with a blinding white hue."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A flesh golem lifts {pronoun} fat fleshy foot and tries to stomp on you!",
        "A flesh golem pounds at you with {pronoun} huge swollen right fist!",
        "A flesh golem pounds at you with {pronoun} fist!",
        "A slimy flesh golem lifts {pronoun} fat fleshy foot and tries to stomp on you!",
        "A slimy flesh golem pounds at you with {pronoun} huge swollen right fist!",
        "A flesh golem pounds at you with {pronoun} huge swollen left fist!",
        "A flesh golem pounds at {target} with {pronoun} huge swollen right fist!"
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
