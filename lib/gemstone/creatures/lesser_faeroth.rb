{
  schema_version: 3,
  name: "lesser faeroth",
  noun: "faeroth",
  url: "https://gswiki.play.net/lesser_faeroth",
  picture: "",
  level: 46,
  family: "Faeroth",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: 6,
  height: 6,
  size: "large",
  areas: [
    {
      name: "Gyldemar Forest",
      uids: [13030041..13030076]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (257..281)
      },
      {
        name: "Claw",
        as: (236..291)
      },
      {
        name: "Pound",
        as: (271..281)
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
    asg: "8N",
    immunities: [],
    melee: 472,
    ranged: (205..258),
    bolt: (210..258),
    udf: (254..421),
    bar_td: (143..153),
    cle_td: (158..167),
    emp_td: (154..160),
    pal_td: (129..138),
    ran_td: (135..144),
    sor_td: (166..187),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 175,
    mjs_td: (157..166),
    mns_td: (157..166),
    mnm_td: (129..138),
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
    skin: nil,
    other: "a mottled faeroth crest",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The lesser faeroth looks as though she is a near relative to a monkey. Standing on powerful forelimbs, her body is lifted entirely off the ground. Two atrophied legs with filthy claws dangle loosely below the body and look to be double-jointed. A spark of malevolent intelligence burns in her eyes."
    ],
    arrival: [
      "A lesser faeroth strides in.",
      "A lesser faeroth just arrived!",
      "A stalwart lesser faeroth strides in.",
      "A robust lesser faeroth strides in."
    ],
    flee: [
      "A lesser faeroth hobbles haphazardly westward.",
      "A lesser faeroth hobbles haphazardly southeastward.",
      "A lesser faeroth hobbles haphazardly northeastward.",
      "A lesser faeroth hobbles haphazardly southwestward."
    ],
    death: [
      "A lesser faeroth emits a shriek as {pronoun} goes still.",
      "A lesser faeroth releases a shriek as {pronoun} falls to the ground and goes still.",
      "A lesser faeroth's face contorts in horror as he goes still.",
      "A robust lesser faeroth releases a shriek as {pronoun} falls to the ground and goes still.",
      "A stalwart lesser faeroth emits a shriek as she goes still.",
      "A stalwart lesser faeroth releases a shriek as {pronoun} falls to the ground and goes still.",
      "A lesser faeroth releases a shriek as she falls to the floor and goes still.",
      "A robust lesser faeroth emits a shriek as she goes still."
    ],
    decay: [
      "A lesser faeroth decays into a pile of foul-smelling compost.",
      "A robust lesser faeroth decays into a pile of foul-smelling compost.",
      "A stalwart lesser faeroth decays into a pile of foul-smelling compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A lesser faeroth swings backward on {pronoun} arms, lips curled in a snarl."
      ],
      bite: [
        "A lesser faeroth tries to bite you!"
      ],
      claw: [
        "A lesser faeroth claws at you!"
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
