{
  schema_version: 3,
  name: "spotted gnarp",
  noun: "gnarp",
  url: "https://gswiki.play.net/spotted_gnarp",
  picture: "",
  level: 1,
  family: "Caprine",
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
  max_hp: 60,
  speed: 15,
  height: 2,
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
        as: 32
      },
      {
        name: "Tusk",
        as: (23..36)
      },
      {
        name: "Unknown",
        as: 23
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
    asg: "10N",
    immunities: [],
    melee: (14..37),
    ranged: 14,
    bolt: 14,
    udf: (40..61),
    bar_td: 3,
    cle_td: 3,
    emp_td: 3,
    pal_td: (0..3),
    ran_td: 3,
    sor_td: 3,
    wiz_td: 3,
    mje_td: 3,
    mne_td: 3,
    mjs_td: 3,
    mns_td: 3,
    mnm_td: 3,
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
    skin: "a spotted gnarp horn",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Oh, what a thing of horror is the curl-horned spotted gnarp! Huge floppy ears stand out from her long snout like horizontal bunny ears, and her eyes are deep, liquid pools of irascibility and indecision. The creature's ponderous spotted belly hangs from a ridge-like backbone, which tapers in a long tail with a curly tip. Swishing her tail viciously, the gnarp minces about on cloven hooves, her massive curled horns overbalancing her head as she tears at the scattered herbage with her large, formidable teeth."
    ],
    arrival: [
      "A spotted gnarp springs in and lands with a clatter of hooves.",
      "A spotted gnarp just came through the barn door.",
      "A spotted gnarp trots in!"
    ],
    flee: [
      "A spotted gnarp trots {direction}.",
      "A spotted gnarp just went through the barn door.",
      "A spotted gnarp snorts as {pronoun} slowly backs away."
    ],
    death: [
      "The spotted gnarp collapses to the ground, emits a final cry, and dies.",
      "The spotted gnarp lets out a final agonized cry and dies.",
      "The spotted gnarp collapses to the ground, emits a final silent cry, and dies."
    ],
    decay: [
      "A spotted gnarp decays into a pile of fur and bone."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A spotted gnarp charges at you with {pronoun} tusk!",
        "A spotted gnarp charges at {target} with {pronoun} tusk!"
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
