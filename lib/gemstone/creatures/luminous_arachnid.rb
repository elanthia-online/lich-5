{
  schema_version: 3,
  name: "luminous arachnid",
  noun: "arachnid",
  url: "https://gswiki.play.net/luminous_arachnid",
  picture: "",
  level: 15,
  family: "Arachnid",
  type: "Arachnid",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 140,
  speed: 6,
  height: 2,
  size: "medium",
  areas: [
    {
      name: "Thurfel's Island",
      uids: [7532001..7532033]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 150
      },
      {
        name: "Ensnare",
        as: (148..152)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Web"
      }
    ],
    special_abilities: [
      {
        name: "Web"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (54..170),
    ranged: (44..83),
    bolt: (44..83),
    udf: (101..228),
    bar_td: 45,
    cle_td: (45..51),
    emp_td: (42..51),
    pal_td: (42..51),
    ran_td: (45..51),
    sor_td: (42..51),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 45,
    mjs_td: (51..66),
    mns_td: (51..66),
    mnm_td: (42..48),
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
    skin: nil,
    other: "s'ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Dotting the pale-skinned arachnid are numerous tiny luminescent diamond-shaped markings. The markings glow with a bluish-green tint."
    ],
    arrival: [],
    flee: [
      "A luminous arachnid crawls {direction}.",
      "A luminous arachnid scurries {direction}.",
      "A luminous arachnid hobbles {direction}."
    ],
    death: [
      "The luminous arachnid collapses to the ground and dies.",
      "The luminous arachnid's body jerks one last time and dies."
    ],
    decay: [
      "A luminous arachnid's legs shrivel up beneath it as it decays into dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "An arachnid tries to ensnare you!"
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
