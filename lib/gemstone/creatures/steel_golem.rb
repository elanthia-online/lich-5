{
  schema_version: 3,
  name: "steel golem",
  noun: "golem",
  url: "https://gswiki.play.net/steel_golem",
  picture: "",
  level: 20,
  family: "Golem",
  type: "Biped",
  undead: false,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: false,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 188,
  speed: 10,
  height: 9,
  size: "large",
  areas: [
    {
      name: "Glatoph",
      uids: [35041..35067]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ensnare",
        as: (168..178)
      },
      {
        name: "Pound",
        as: 188
      },
      {
        name: "Stomp",
        as: 198
      },
      {
        name: "Metallic hand",
        as: (150..169)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Twin Hammerfists"
      },
      {
        name: "Ground Slam"
      }
    ],
    special_abilities: [
      {
        name: "Foot slam"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "19N",
    immunities: [],
    melee: (65..208),
    ranged: (62..97),
    bolt: (62..97),
    udf: (101..208),
    bar_td: nil,
    cle_td: (54..60),
    emp_td: 60,
    pal_td: (57..60),
    ran_td: (54..63),
    sor_td: (55..67),
    wiz_td: nil,
    mje_td: (56..69),
    mne_td: (56..69),
    mjs_td: (54..60),
    mns_td: (54..60),
    mnm_td: (60..63),
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
    other: [
      "crystal core (alchemy)",
      "glimmering blue essence dust"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The squeal of rusty gears and the shriek of cracked pipes expelling steam is nearly deafening, but the sharp sound of a steel golem's claws rhythmically sharpening themselves against each other still grate distinctly throughout the area. Thick plates of armor cover the golem, but nothing could hide the mass of mechanized motion underneath. In a horrifying mimicry of life, a lining of sharp steel teeth are embedded within its large jaw, just underneath eye sockets that slowly expel a stream of black smoke."
    ],
    arrival: [
      "A steel golem arrives, emitting a horrible screeching noise.",
      "A steel golem strides in, head swiveling and gears twirling rapidly."
    ],
    flee: [],
    death: [
      "A steel golem freezes completely before falling to the floor in pieces."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A steel golem pounds at you with {pronoun} metallic hand!",
        "The gears of a steel golem spin viciously as it tries to ensnare you!"
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
