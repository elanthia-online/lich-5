{
  schema_version: 3,
  name: "greater faeroth",
  noun: "faeroth",
  url: "https://gswiki.play.net/greater_faeroth",
  picture: "",
  level: 50,
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
  boss_type: "miniboss",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: 10,
  height: 7,
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
        as: (302..342)
      },
      {
        name: "Claw",
        as: (318..340)
      },
      {
        name: "Pound",
        as: (305..338)
      },
      {
        name: "Fist",
        as: 297
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
    asg: "12N",
    immunities: [],
    melee: (269..472),
    ranged: (164..274),
    bolt: (164..274),
    udf: (243..375),
    bar_td: nil,
    cle_td: 175,
    emp_td: (173..182),
    pal_td: (147..153),
    ran_td: (147..153),
    sor_td: (175..193),
    wiz_td: nil,
    mje_td: (194..195),
    mne_td: (194..195),
    mjs_td: (164..184),
    mns_td: (164..184),
    mnm_td: (147..150),
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
    skin: "a faeroth fang",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The greater faeroth looks as though he might be a relative to a yeti, although his fur is a mottled dingy brown and carries a pungent stench. Similar to its lesser cousin, the greater faeroth stands on mighty forelimbs that lift his entire body into the air. Much more powerful hind legs dangle with sharp, filthy claws extruding. The beast stands at least seven feet tall, with a face that might look human if not for the heavy brow and deeply set eyes. Black lips curl over ivory white teeth that appear to drip some sort of vile green liquid."
    ],
    arrival: [
      "A greater faeroth pounds in on {pronoun} massive forelimbs, roaring ferociously!",
      "A greater faeroth pounds in."
    ],
    flee: [
      "A greater faeroth pounds southwestward.",
      "A greater faeroth pounds northward.",
      "A greater faeroth pounds southeastward.",
      "A greater faeroth pounds southward.",
      "A greater faeroth pounds northeastward.",
      "A greater faeroth pounds westward.",
      "A greater faeroth pounds northwestward.",
      "A greater faeroth pounds eastward.",
      "A greater faeroth hobbles haphazardly northeastward.",
      "A greater faeroth hobbles haphazardly southward.",
      "A greater faeroth hobbles haphazardly westward.",
      "A greater faeroth hobbles haphazardly southwestward.",
      "A greater faeroth hobbles haphazardly northward."
    ],
    death: [
      "A greater faeroth emits a roar as {pronoun} goes still.",
      "A greater faeroth releases a roar as {pronoun} falls to the ground and goes still.",
      "An apt greater faeroth emits a roar as she goes still."
    ],
    decay: [
      "A greater faeroth decays into a pile of foul-smelling compost.",
      "An apt greater faeroth decays into a pile of foul-smelling compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A greater faeroth pounds at you with {pronoun} fist!",
        "A greater faeroth swings backward on {pronoun} arms, lips curled in a snarl.",
        "A greater faeroth bellows causing the air to distort, sending a shockwave at you!"
      ],
      bite: [
        "A greater faeroth tries to bite you!"
      ],
      claw: [
        "A greater faeroth claws at you!"
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
