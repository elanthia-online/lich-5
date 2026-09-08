{
  schema_version: 3,
  name: "striped gak",
  noun: "gak",
  url: "https://gswiki.play.net/striped_gak",
  picture: "",
  level: 3,
  family: "Bovine",
  type: "Quadruped",
  undead: false,
  blood: nil,
  bones: true,
  limbs: true,
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
  max_hp: 81,
  speed: 10,
  height: 4,
  size: "large",
  areas: [
    {
      name: "Graendlor Pasture",
      uids: [4301001..4301025]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Impale",
        as: 61
      },
      {
        name: "Tusk",
        as: 54
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
    asg: "6N",
    immunities: [],
    melee: (11..40),
    ranged: (11..14),
    bolt: (11..14),
    udf: (48..73),
    bar_td: nil,
    cle_td: 9,
    emp_td: 9,
    pal_td: (6..9),
    ran_td: 9,
    sor_td: 9,
    wiz_td: nil,
    mje_td: 9,
    mne_td: 9,
    mjs_td: 9,
    mns_td: 9,
    mnm_td: 9,
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
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a gak pelt",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The striped gak is a big, ugly beast with a heavy striped brown pelt. A marked odor of dung and musty wool surrounds him in a noxious cloud. The gak chomps vicious-looking teeth, a mix of distrust and hatred in his large doe-like eyes. A pair of sharp horns curves up above his short, broad head in a shape that resembles a lyre. The animal looks ungainly with his tall shoulders and shorter hindquarters, which give his a jerky, uneven gait. Suddenly, he bares his bovine ivories and brays loudly!"
    ],
    arrival: [
      "A striped gak charges in, flaring {pronoun} nostrils angrily!"
    ],
    flee: [
      "A striped gak gallops {direction}.",
      "A striped gak snorts as {pronoun} slowly backs away."
    ],
    death: [
      "The striped gak collapses to the ground, emits a final bellow, and dies.",
      "The striped gak lets out a final agonized bellow and dies.",
      "The striped gak collapses to the ground, emits a final silent bellow, and dies."
    ],
    decay: [
      "A striped gak decays into a pile of fur and bone."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A striped gak charges at you with {pronoun} tusk!",
        "A striped gak charges at {target} with {pronoun} tusk!"
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
