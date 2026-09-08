{
  schema_version: 3,
  name: "brown gak",
  noun: "gak",
  url: "https://gswiki.play.net/brown_gak",
  picture: "",
  level: 2,
  family: "Bovine",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 70,
  speed: 12,
  height: 4,
  size: "large",
  areas: [
    {
      name: "Yander's Farm",
      uids: [14005002..14005019]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Impale",
        as: 48
      },
      {
        name: "Tusk",
        as: 43
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
    melee: (11..36),
    ranged: 11,
    bolt: 11,
    udf: (41..63),
    bar_td: 6,
    cle_td: 6,
    emp_td: 6,
    pal_td: (3..6),
    ran_td: 6,
    sor_td: 6,
    wiz_td: 6,
    mje_td: 6,
    mne_td: 6,
    mjs_td: (3..6),
    mns_td: (3..6),
    mnm_td: 6,
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
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "a brown gak hide",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The brown gak is a big, ugly beast with a dirt-encrusted brown pelt. A marked odor of dung and musty wool surround him in a noxious cloud. The gak chomps vicious-looking teeth, a mix of distrust and hatred in his large doe-like eyes. A pair of sharp horns curves up above his short, broad head in a shape that resembles a lyre. The animal looks ungainly with his tall shoulders and shorter hindquarters, which give his a jerky, uneven gait. Suddenly, he bares his bovine ivories and brays loudly!"
    ],
    arrival: [
      "A brown gak just came through the barn door.",
      "A brown gak charges in, a wild look in {pronoun} eyes."
    ],
    flee: [
      "A brown gak gallops {direction}.",
      "A brown gak just went through the barn door."
    ],
    death: [
      "The brown gak collapses to the ground, emits a final bellow, and dies.",
      "The brown gak lets out a final agonized bellow and dies.",
      "The brown gak collapses to the ground, emits a final silent bellow, and dies."
    ],
    decay: [
      "A brown gak decays into a pile of fur and bone."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A brown gak charges at you with {pronoun} tusk!"
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
