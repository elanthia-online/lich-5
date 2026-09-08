{
  schema_version: 3,
  name: "shadow steed",
  noun: "steed",
  url: "https://gswiki.play.net/shadow_steed",
  picture: "",
  level: 38,
  family: "Equine",
  type: "Quadruped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
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
  max_hp: 400,
  speed: 8,
  height: 6,
  size: "large",
  areas: [
    {
      name: "Shadow Valley",
      uids: [389030..389035, 2160001..2160035, 2161001..2161022]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge",
        as: 254
      },
      {
        name: "Foot",
        as: (228..242)
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
    asg: nil,
    immunities: [],
    melee: (140..293),
    ranged: (128..216),
    bolt: (128..216),
    udf: (192..290),
    bar_td: nil,
    cle_td: (127..141),
    emp_td: (131..141),
    pal_td: (119..122),
    ran_td: (112..121),
    sor_td: (144..151),
    wiz_td: nil,
    mje_td: (154..157),
    mne_td: (154..157),
    mjs_td: (130..140),
    mns_td: (130..140),
    mnm_td: (115..125),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: "a silvery tail",
    other: [
      "Glowing violet essence dust",
      "ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "As magnificent as any living horse, this shadow steed stares beyond you with glowing red eyes. Its matte black coat provides a sharp contrast to its shining silvery tail and mane. The shadow steed paws the ground restlessly with its front hooves as it swishes its tail, flickering into and out of the shadows."
    ],
    arrival: [],
    flee: [],
    death: [
      "A shadow steed fades into oblivion."
    ],
    decay: [
      "A shadow steed fades into oblivion."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A shadow steed charges at you!",
        "A shadow steed stomps at you with {pronoun} foot!"
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
