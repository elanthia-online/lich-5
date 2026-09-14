{
  schema_version: 3,
  name: "shrickhen",
  noun: "shrickhen",
  url: "https://gswiki.play.net/shrickhen",
  picture: "",
  level: 76,
  family: "Chimeric",
  type: "Hybrid",
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
    "Corporeal undead",
    "Magical"
  ],
  bcs: true,
  max_hp: 300,
  speed: 8,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Maaghara Tower",
      uids: [13022008..13022049]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 393
      },
      {
        name: "Claw",
        as: 403
      },
      {
        name: "Severed shrickhen arm",
        as: (50..411)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Elemental Dispel (417)"
      },
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Major Elemental Wave (435)"
      }
    ],
    maneuvers: [
      {
        name: "Point"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (260..450),
    ranged: (227..294),
    bolt: (227..294),
    udf: (397..648),
    bar_td: (281..285),
    cle_td: (295..320),
    emp_td: (296..303),
    pal_td: (268..277),
    ran_td: (260..270),
    sor_td: (306..338),
    wiz_td: nil,
    mje_td: 344,
    mne_td: nil,
    mjs_td: (290..315),
    mns_td: (290..315),
    mnm_td: (245..253),
    defensive_spells: [
      "Elemental Defense II",
      "Elemental Defense III",
      "Elemental Targetting"
    ],
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
    skin: nil,
    other: "inky necrotic core",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Seemingly cobbled together from leftover bodily parts, no two shrickhen are alike. One may have the lower body of a troll supporting the torso of a fire salamander from which a dark orc's arm extends on one side and a gremlin's arm extends on the other, all topped by a timberwolf's head. A second may have a mezic's leg, a coyote's leg, a pyrothag's arm, and a shan warrior's arm, each connected in almost the right place to the torso of a krolvin warfarer, with the entire grouping utilizing the one-eyed head of a cyclops for navigation. These hideous conglomerations definitely have two things in common: a total lack of fear and an insatiable need to consume flesh."
    ],
    arrival: [
      "A shrickhen rushes in, snarling and gibbering!",
      "A shrickhen rushes in, {pronoun} form weaving and shaking as {pronoun} parts attempt to work together."
    ],
    flee: [],
    death: [
      "A shrickhen's arms, legs and head separate from {pronoun} torso as the dissimilar parts finally fall still."
    ],
    decay: [
      "A shrickhen's parts decay away."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A shrickhen rushes {direction}, {pronoun} form weaving and shaking as {pronoun} parts attempt to work together.",
        "A shrickhen screams furiously and points at you!"
      ],
      bite: [
        "A shrickhen tries to bite you!"
      ],
      claw: [
        "A shrickhen claws at you!"
      ],
      hurl: [
        "A shrickhen throws {weapon} at you!"
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
