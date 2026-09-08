{
  schema_version: 3,
  name: "warthog",
  noun: "warthog",
  url: "https://gswiki.play.net/warthog",
  picture: "",
  level: 22,
  family: "Suine",
  type: "Quadruped",
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
  max_hp: 270,
  speed: 12,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Emerald Forest",
      uids: [13301201..13301232, 13301301..13301335]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge (attack)",
        as: 226
      },
      {
        name: "Impale (attack)",
        as: 216
      },
      {
        name: "Charge",
        as: 206
      },
      {
        name: "Tusk",
        as: 208
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Charge"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (73..154),
    ranged: (92..96),
    bolt: (92..96),
    udf: (147..196),
    bar_td: 63,
    cle_td: (63..72),
    emp_td: (66..74),
    pal_td: (60..69),
    ran_td: (60..66),
    sor_td: 66,
    wiz_td: nil,
    mje_td: (66..69),
    mne_td: (66..69),
    mjs_td: (60..66),
    mns_td: (60..66),
    mnm_td: (60..69),
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
    skin: "a warthog snout",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The warthog stands level-backed on short, thick legs. His large, angular head is balanced on each side by curved tusks. Used for goring or gashing his enemies, the tusks provide the warthog's primary means of defense. The warthog's bright, attentive eyes are set back and up on his head. Around the edges of the eyes are rows of warts that give this creature his name. Mainly found living in woods or underground burrows, the warthog prefers dark and damp areas to hide in and to provide him concealment until he rushes out after his prey."
    ],
    arrival: [
      "A warthog just arrived.",
      "A warthog crashes into view!"
    ],
    flee: [
      "A warthog grunts and barrels {direction}.",
      "A warthog trots {direction}, grunting noisily.",
      "A warthog trots {direction}, grunting noisily!",
      "A warthog snuffles as {pronoun} slowly backs away."
    ],
    death: [
      "The warthog collapses to the ground, emits a final snuffle, and dies.",
      "The warthog lets out a final agonized snuffle and dies."
    ],
    decay: [
      "A warthog decays into a pile of fur and bone."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A warthog charges at you with {pronoun} tusk!",
        "A warthog charges at you!",
        "A warthog charges at {target} with {pronoun} tusk!",
        "A warthog charges towards you, but you leap to the side at the last instant, avoiding a gruesome fate! The warthog stumbles and falls!"
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
