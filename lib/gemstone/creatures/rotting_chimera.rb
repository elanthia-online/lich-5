{
  schema_version: 3,
  name: "rotting chimera",
  noun: "chimera",
  url: "https://gswiki.play.net/rotting_chimera",
  picture: "",
  level: 46,
  family: "Chimeric",
  type: "Quadruped",
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
  max_hp: 400,
  speed: 6,
  height: 4,
  size: "large",
  areas: [
    {
      name: "Marsh Keep",
      uids: [376001..376001, 376003..376010, 376015..376018, 376020..376034, 376040..376044]
    },
    {
      name: "unmapped",
      uids: [376002..376002, 376019..376019, 376035..376039]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 276
      },
      {
        name: "Claw",
        as: (244..276)
      },
      {
        name: "Pound",
        as: 276
      },
      {
        name: "Bestial jaws",
        as: 248
      },
      {
        name: "Enormous humanoid fist",
        as: (230..248)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Scorpion Stinger"
      },
      {
        name: "Webbing"
      },
      {
        name: "Tail Swipe"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (173..382),
    ranged: (177..255),
    bolt: (177..255),
    udf: (329..398),
    bar_td: nil,
    cle_td: (168..177),
    emp_td: (167..170),
    pal_td: (142..151),
    ran_td: 112,
    sor_td: (167..185),
    wiz_td: nil,
    mje_td: 186,
    mne_td: 186,
    mjs_td: (161..170),
    mns_td: (161..170),
    mnm_td: (135..138),
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
    skin: "a chimera stinger",
    other: "glowing violet essence dust",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The twisted and confused form of the rotting chimera is a testament to the sacrilege of mortals trying to wield the power of the gods. While its body looks to be primarily formed of a huge jaguar carcass, the degraded nature of the chimera does little to hide the disfigured appearance of a creature crafted from the parts of many beasts. Scales disperse into ragged patches of fur that thin out into dangling flesh. An enormous humanoid arm extends from one of the front shoulder blades of the beast while beneath it, her four legs are borrowed appendages from as many species. A huge scorpion tail rises high from the rear of the chimera, ready to strike. Sorrow-ridden eyes, one slitted, the other round, gaze into the distance as an uneven tempo of labored wheezing fills the fetid air.\n\nThere are two types of rotting chimera. The above description is for the chimeras that have scorpion tails. For the webbing chimeras, the \"A huge scorpion tail rises high from the rear of the chimera, ready to strike.\" line is replaced with:\n\nThe swollen abdomen of a mammoth arachnid has been grafted to the hind-quarters of the the chimera."
    ],
    arrival: [
      "A rotting chimera stomps in.",
      "A rotting chimera arrives, dragging {reflexive} in and sobbing slightly from pain."
    ],
    flee: [
      "A rotting chimera crawls {direction}.",
      "A rotting chimera lowers its head and stomps {direction}."
    ],
    death: [
      "A rotting chimera collapses into a pile of skin and bones.",
      "A rotting chimera slumps wearily to the ground and ceases to move."
    ],
    decay: [
      "A rotting chimera collapses into a pile of skin and bones."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A rotting chimera bites at you with {pronoun} bestial jaws!",
        "A rotting chimera pounds at you with an enormous humanoid fist!"
      ],
      bite: [
        "A rotting chimera bites at you with {pronoun} bestial jaws!"
      ],
      claw: [
        "A rotting chimera claws at you!"
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
