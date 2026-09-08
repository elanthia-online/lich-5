{
  schema_version: 3,
  name: "crystal golem",
  noun: "golem",
  url: "https://gswiki.play.net/crystal_golem",
  picture: "",
  level: 12,
  family: "Golem",
  type: "Biped",
  undead: false,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: false,
  sympathy: false,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Magical"
  ],
  bcs: true,
  max_hp: 140,
  speed: 11,
  height: 9,
  size: "large",
  areas: [
    {
      name: "Crystal Caves",
      uids: [24058..24064]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ensnare",
        as: 140
      },
      {
        name: "Pound",
        as: 134
      },
      {
        name: "Stomp",
        as: 144
      },
      {
        name: "Crystalline fist",
        as: 117
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Foot stomp"
      },
      {
        name: "Ground Slam"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "14N",
    immunities: [],
    melee: (53..130),
    ranged: (49..67),
    bolt: (49..67),
    udf: (78..158),
    bar_td: nil,
    cle_td: (33..36),
    emp_td: nil,
    pal_td: (33..36),
    ran_td: (36..39),
    sor_td: (30..42),
    wiz_td: nil,
    mje_td: (30..42),
    mne_td: (30..42),
    mjs_td: (33..42),
    mns_td: (33..42),
    mnm_td: (36..39),
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
    other: "a crystal core",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Towering about three yards tall, a crystal golem's form is nothing short of massive. Deeply set fires glimmer coldly from its eye sockets, throwing a myriad of colors throughout the large crystal spikes jutting sharply away from its thick crystalline skin. As it moves, the rainbow color flickers through the facets of its body in a dizzying array of color."
    ],
    arrival: [
      "A crystal golem stomps in, fiery eyes the only clue to its deadly intent."
    ],
    flee: [
      "A crystal golem stomps {direction}."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [
      "A crystal golem's eyes flare in a final puff of fire before {pronoun} falls to the floor, motionless.",
      "A crystal golem's eyes flare in a final puff of fire before {pronoun} goes motionless."
    ],
    attacks: {
      attack: [
        "A crystal golem pounds at you with {pronoun} crystalline fist!",
        "A crystal golem tries to ensnare you in {pronoun} thick arms!"
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
