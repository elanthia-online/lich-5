{
  schema_version: 3,
  name: "patchwork flesh monstrosity",
  noun: "monstrosity",
  url: "https://gswiki.play.net/patchwork_flesh_monstrosity",
  picture: "",
  level: 98,
  family: "Chimeric",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 500,
  speed: 6,
  height: 15,
  size: "huge",
  areas: [
    {
      name: "Shadow of the Sanctum",
      uids: [4216001..4216049]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ensnare (attack)Ensnare",
        as: 450
      },
      {
        name: "Stomp (attack)Stomp"
      },
      {
        name: "Bloated arms",
        as: (438..480)
      },
      {
        name: "Bronze cutlass",
        as: 543
      },
      {
        name: "Heel of his hand",
        as: 418
      },
      {
        name: "Kick",
        as: 390
      },
      {
        name: "Heel of her hand",
        as: 427
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tackle"
      },
      {
        name: "Twin Hammerfists"
      },
      {
        name: "Charge"
      },
      {
        name: "Disarm"
      },
      {
        name: "Stomp"
      }
    ],
    special_abilities: [
      {
        name: "Tremors"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "5",
    immunities: [],
    melee: (81..562),
    ranged: (92..372),
    bolt: (92..372),
    udf: (291..646),
    bar_td: nil,
    cle_td: (409..418),
    emp_td: (401..407),
    pal_td: (353..362),
    ran_td: (347..361),
    sor_td: (421..430),
    wiz_td: nil,
    mje_td: (444..448),
    mne_td: (444..448),
    mjs_td: 453,
    mns_td: 453,
    mnm_td: (300..309),
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
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A patchwork flesh monstrosity is near as tall as a giant and twice as broad, a lumbering monstrosity cobbled together from spare parts in tactless parody of a human form. Red-tinged serum leaks constantly from the straining stitches that maintain the monster's integrity. Only the barest glimmer of intelligence lurks in the monstrosity's eyes, and that, perhaps, is a blessing: anything with even half of a brain would be horrified to be such an abominable figure. From the looks of it, the monstrosity's has barely a quarter of one."
    ],
    arrival: [
      "A patchwork flesh monstrosity shakes the ground as {pronoun} trundles in, belching serum from {pronoun} stitched flesh with every heavy step.",
      "A patchwork flesh monstrosity trundles in, shaking the floor with {pronoun} footsteps.",
      "A patchwork flesh monstrosity just came through a polished acacia archway.",
      "A patchwork flesh monstrosity trundles in, shaking the ground with {pronoun} footsteps.",
      "A patchwork flesh monstrosity just came through some riveted black ora doors.",
      "A patchwork flesh monstrosity just came through a pair of high bronze double doors."
    ],
    flee: [
      "A patchwork flesh monstrosity just went through a pair of high bronze double doors.",
      "A patchwork flesh monstrosity just went through some riveted black ora doors.",
      "A patchwork flesh monstrosity trundles noisily {direction}.",
      "A patchwork flesh monstrosity stomps the ground, sending vibrations trembling outward from the point of impact."
    ],
    death: [],
    decay: [],
    search: [
      "A patchwork flesh monstrosity looks around, obviously confused."
    ],
    spell_prep: [],
    stun_break: [
      "A patchwork flesh monstrosity's purloined muscles cord violently and {pronoun} rips free from {pronoun} magical maladies!"
    ],
    attacks: {
      attack: [
        "A patchwork flesh monstrosity tries to ensnare you with {pronoun} bloated arms!",
        "Raising one immense foot, a patchwork flesh monstrosity tries to stomp on you!",
        "A patchwork flesh monstrosity slams {pronoun} foot down, sending tremors rumbling through the area!",
        "A patchwork flesh monstrosity barrels into motion, flinging {reflexive} at you!",
        "A patchwork flesh monstrosity raises a hamhock-sized fist overhead and brings {pronoun} swiftly down at you!",
        "A patchwork flesh monstrosity barrels into motion, flinging {reflexive} at {target}!",
        "A patchwork flesh monstrosity tries to ensnare {target} with {pronoun} bloated arms!",
        "A patchwork flesh monstrosity raises a hamhock-sized fist overhead and brings {pronoun} swiftly down at {target}!",
        "The patchwork flesh monstrosity crushes {target} beneath {pronoun} fetid body and struggles to {pronoun} feet, leaving {target} weakened and sprawled out on the ground."
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
