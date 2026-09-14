{
  schema_version: 3,
  name: "elder tree spirit",
  noun: "spirit",
  url: "https://gswiki.play.net/elder_tree_spirit",
  picture: "",
  level: 30,
  family: "Tree",
  type: "Plantlife",
  undead: true,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 350,
  speed: nil,
  height: 12,
  size: "huge",
  areas: [
    {
      name: "Abandoned Farm",
      uids: [4124101..4124112, 4124114..4124124]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ensnare (attack)"
      },
      {
        name: "Ensnare",
        as: 182
      }
    ],
    bolt_spells: [
      {
        name: "Major Shock (910)",
        as: (208..220)
      }
    ],
    warding_spells: [
      {
        name: "Unbalance (110)",
        cs: (157..169)
      }
    ],
    offensive_spells: [
      {
        name: "Earthen Fury (917)"
      },
      {
        name: "Call Lightning (125)"
      }
    ],
    maneuvers: [
      {
        name: "Gesture"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "11N",
    immunities: [],
    melee: (61..162),
    ranged: (51..105),
    bolt: (51..105),
    udf: 97,
    bar_td: 99,
    cle_td: (109..115),
    emp_td: (108..117),
    pal_td: (90..99),
    ran_td: (87..96),
    sor_td: (109..115),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 120,
    mjs_td: (129..138),
    mns_td: (129..138),
    mnm_td: (84..90),
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
    other: "Glimmering blue essence dust",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The undead tree spirit resides among its living brethren, barely distinguishable from them until it is awakened from its slumber. It resembles many different types of towering trees, for a tree spirit is able to take on the shape and appearance of the forest around it. Being spirit, though, it is not quite solid, not quite sharply defined, and its appearance shifts slightly as it moves. Many are fooled by a tree spirit's soft, soothing whispering, only to realize with horror that it is the preparation of a lethal spell."
    ],
    arrival: [
      "An elder tree spirit just arrived."
    ],
    flee: [
      "An elder tree spirit heads {direction}."
    ],
    death: [
      "The tree spirit slowly settles to the ground and begins to dissipate."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "An elder tree spirit gestures at you!",
        "An elder tree spirit tries to ensnare you!"
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
