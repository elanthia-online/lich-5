{
  schema_version: 3,
  name: "fire sprite",
  noun: "sprite",
  url: "https://gswiki.play.net/fire_sprite",
  picture: "",
  level: 64,
  family: "Fey",
  type: "Biped",
  undead: false,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Element-based"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "tiny",
  areas: [
    {
      name: "Eye of V'Tull",
      uids: [3051003..3051030, 3061025..3061035]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: (294..327)
      }
    ],
    bolt_spells: [
      {
        name: "Major Fire"
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Elemental Dispel"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (327..403),
    ranged: (271..316),
    bolt: (274..316),
    udf: (340..477),
    bar_td: nil,
    cle_td: (252..261),
    emp_td: (261..268),
    pal_td: (213..221),
    ran_td: (216..225),
    sor_td: (268..275),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 290,
    mjs_td: (256..287),
    mns_td: (256..287),
    mnm_td: (214..215),
    defensive_spells: [
      "Elemental Defense I",
      "Elemental Defense II",
      "Elemental Defense III",
      "Thurfel's Ward"
    ],
    defensive_abilities: [],
    special_defenses: [
      "Immune to Limb Disruption"
    ]
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Glowing violet mote of essence",
      "essence of fire",
      "pristine sprite's hair"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "At first glance, the fire sprite looks like nothing more than a ball of whirling flame, spitting smoke and ricocheting about the rocks like a dervish. Gradually, her form coalesces, extending elongated arms and fingers, and short gnarled legs from the sphere of fire. The fire sprite's hideous features are pulled into a grimace of hate, and her eyes are like two glowing coals, which spout sparks as the creature wavers in and out of her tenuous configuration."
    ],
    arrival: [],
    flee: [
      "A fire sprite flits {direction}."
    ],
    death: [
      "The fire sprite goes limp and she falls over as the fire slowly fades from her eyes."
    ],
    decay: [],
    search: [
      "A fire sprite looks around apprehensively as {pronoun} takes a step back."
    ],
    spell_prep: [
      "A fire sprite glows with a fiery red light."
    ],
    attacks: {
      attack: [
        "A fire sprite swings {weapon} at you!",
        "A fire sprite leaves a trail of flames while gesturing with both hands at you!"
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
