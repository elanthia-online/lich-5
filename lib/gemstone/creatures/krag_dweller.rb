{
  schema_version: 3,
  name: "krag dweller",
  noun: "dweller",
  url: "https://gswiki.play.net/krag_dweller",
  picture: "",
  level: 72,
  family: "Dweller",
  type: "Biped",
  undead: false,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 403,
  speed: 12,
  height: 9,
  size: "large",
  areas: [
    {
      name: "Stormpeak",
      uids: [13150301..13150322]
    },
    {
      name: "Krag Slopes",
      uids: [495101..495116]
    },
    {
      name: "The Hidden Plateau",
      uids: [2167001..2167022]
    },
    {
      name: "unmapped",
      uids: [13150323..13150324]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound",
        as: 400
      },
      {
        name: "Fist",
        as: 383
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Krag dweller boulder"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "20N",
    immunities: [
      "Dark Catalyst (719)",
      "Implosion (720)",
      "Fire",
      "Web (118)"
    ],
    melee: (146..445),
    ranged: (179..262),
    bolt: (179..262),
    udf: (300..561),
    bar_td: (246..264),
    cle_td: (278..281),
    emp_td: (274..283),
    pal_td: (240..249),
    ran_td: (246..249),
    sor_td: (280..301),
    wiz_td: nil,
    mje_td: 317,
    mne_td: 317,
    mjs_td: (274..280),
    mns_td: (274..280),
    mnm_td: 228,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: nil,
    other: "Essence of earth",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The krag dweller appears to be a cross between a troll and elemental rock. It towers over 8 feet tall with massive limbs. Jet black hairs grow between the plates of its brown scaly hide while long razor sharp fangs and claws provide the krag dweller with all the weapons it will ever need. Even darker than the blackest night, its eyes reveal the smouldering malice within."
    ],
    arrival: [
      "The boulder comes to a sudden stop and rises into the form of a krag dweller!",
      "A krag dweller lumbers in, causing the ground to tremble with each passing step!"
    ],
    flee: [
      "A krag dweller lumbers {direction}, causing the ground to tremble with each passing step!"
    ],
    death: [],
    decay: [
      "The krag dweller crumbles into a pile of rubble.",
      "The krag dweller crumbles away into dust.",
      "The krag dweller collapses into a pile of rubble."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A krag dweller pounds at you with {pronoun} fist!"
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
