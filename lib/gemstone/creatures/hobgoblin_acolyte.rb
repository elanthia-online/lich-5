{
  schema_version: 3,
  name: "hobgoblin acolyte",
  noun: "acolyte",
  url: "https://gswiki.play.net/hobgoblin_acolyte",
  picture: "",
  level: 7,
  family: "Goblin",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 100,
  speed: 6,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Muddy Village",
      uids: [7128001..7128015, 7128026..7128030]
    },
    {
      name: "unmapped",
      uids: [7128016..7128025]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Leather whip"
      }
    ],
    bolt_spells: [
      {
        name: "Minor Shock (901)",
        as: 104
      },
      {
        name: "Minor Water (903)",
        as: 104
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "5",
    immunities: [],
    melee: (48..87),
    ranged: 36,
    bolt: (17..36),
    udf: (45..100),
    bar_td: nil,
    cle_td: (36..46),
    emp_td: 36,
    pal_td: (36..46),
    ran_td: (36..46),
    sor_td: (32..39),
    wiz_td: nil,
    mje_td: 28,
    mne_td: (28..33),
    mjs_td: (36..46),
    mns_td: (36..46),
    mnm_td: (28..33),
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)",
      "Spirit Shield (202)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bone vest",
    "a leather whip",
    "a lynx skull"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "ear",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      ""
    ],
    arrival: [],
    flee: [
      "A hobgoblin acolyte snarls as he retreats!",
      "A hobgoblin acolyte struts {direction}.",
      "A hobgoblin acolyte hobbles slowly {direction}, uttering a prayer under {pronoun} breath."
    ],
    death: [
      "The hobgoblin acolyte screams up at the heavens, then collapses and dies.",
      "The hobgoblin acolyte crumples to the ground and dies.",
      "The hobgoblin acolyte struggles to utter a final prayer, then goes still.",
      "The hobgoblin acolyte gasps a final prayer, then falls to the ground dead."
    ],
    decay: [
      "A hobgoblin acolyte decays into a pile of compost."
    ],
    search: [
      "A hobgoblin acolyte sniffs at the air and glances about with a hungry gleam in {pronoun} eyes."
    ],
    spell_prep: [],
    attacks: {
      attack: [
        "A hobgoblin acolyte finishes chanting and thrusts {weapon} towards you!",
        "A hobgoblin acolyte raises a clenched fist into the air!"
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
