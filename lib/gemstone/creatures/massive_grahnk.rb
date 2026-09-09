{
  schema_version: 3,
  name: "massive grahnk",
  noun: "grahnk",
  url: "https://gswiki.play.net/massive_grahnk",
  picture: "",
  level: 20,
  family: "Grahnk",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 315,
  speed: 10,
  height: 9,
  size: "large",
  areas: [
    {
      name: "Thurfel's Island",
      uids: [7532001..7532033]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Cudgel"
      },
      {
        name: "Foot",
        as: 151
      },
      {
        name: "Heavy stone club",
        as: 192
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tackle"
      },
      {
        name: "Pounce"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "17",
    immunities: [],
    melee: (38..124),
    ranged: (37..69),
    bolt: (37..69),
    udf: (115..183),
    bar_td: (54..60),
    cle_td: 60,
    emp_td: (60..68),
    pal_td: (54..63),
    ran_td: (60..66),
    sor_td: (54..63),
    wiz_td: nil,
    mje_td: 60,
    mne_td: 60,
    mjs_td: (57..66),
    mns_td: (57..66),
    mnm_td: (54..60),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a coral shield",
    "a heavy stone club",
    "a squid-crested breastplate"
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
      "Taller than a giant, the massive grahnk bears similarities to both a troll and an ogre. The beast has rippling muscles easily capable of tearing an arm or leg from its socket."
    ],
    arrival: [
      "A massive grahnk lumbers in, malice in {pronoun} eyes!",
      "A massive grahnk storms in, looking angered as {pronoun} surveys the area!"
    ],
    flee: [
      "A massive grahnk lumbers {direction}, malice in her eyes.",
      "A massive grahnk roars with pain and staggers {direction}."
    ],
    death: [
      "The massive grahnk growls one last time in defiance, then goes still.",
      "The massive grahnk growls one last time in defiance, then slumps to the ground."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      tackle: [
        "A massive grahnk hurls {reflexive} at {target}!"
      ],
      attack: [
        "A massive grahnk stomps at you with {pronoun} foot!",
        "A massive grahnk swings {weapon} at you!",
        "A massive grahnk swings a heavy stone club at {target}!"
      ],
      hurl: [
        "A massive grahnk hurls {weapon} at {target}!"
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
    triggers: {},
    frenzy: "A massive grahnk whales away, consumed with bloodlust!"
  }
}
