{
  schema_version: 3,
  name: "seraceris",
  noun: "seraceris",
  url: "https://gswiki.play.net/seraceris",
  picture: "",
  level: 78,
  family: "Ghost",
  type: "Biped",
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
  bcs: true,
  max_hp: 240,
  speed: 7,
  height: 7,
  size: "medium",
  areas: [
    {
      name: "The Rift",
      uids: [4566001..4566055]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw (attack)",
        as: 291
      },
      {
        name: "Claw",
        as: (380..384)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Holding Song (1001)",
        cs: 346
      },
      {
        name: "Vibration Chant (1002)",
        cs: 346
      },
      {
        name: "Curse (715)",
        cs: 341
      },
      {
        name: "Evil Eye (717)"
      },
      {
        name: "Disintegrate (705)",
        cs: 341
      },
      {
        name: "Point",
        cs: 346
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Air Blast"
      },
      {
        name: "Anti-mana Wave"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "2",
    immunities: [],
    melee: (273..549),
    ranged: (279..492),
    bolt: (279..492),
    udf: (412..464),
    bar_td: nil,
    cle_td: (324..333),
    emp_td: (324..331),
    pal_td: (277..284),
    ran_td: (282..291),
    sor_td: (339..351),
    wiz_td: nil,
    mje_td: (364..365),
    mne_td: (364..365),
    mjs_td: (317..336),
    mns_td: (317..336),
    mnm_td: (289..297),
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Spirit Warding II (107)",
      "Lesser Shroud (120)",
      "Wall of Force (140)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "some tattered flowing robes"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The seraceris stands tall and slender, its body appearing almost two-dimensional as it moves. In the creature's angular face sit two pools of blinding white light, and rays extend from the eye sockets in stark beams which arc around it in a nightmarish aurora. Waves of energy shed by the malign magic permeating the seraceris lift its ragged robes in a jagged halo, echoing its long, gnarled fingers as they dance in a constant blur of spell-summoning."
    ],
    arrival: [],
    flee: [
      "A seraceris glides {direction}."
    ],
    death: [
      "A seraceris fades into oblivion."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A seraceris exhales the last of a virulent green mist."
      ],
      cast: [
        "A seraceris points a ghostly finger at {target}!"
      ],
      claw: [
        "A seraceris claws at you!"
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
