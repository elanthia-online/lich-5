{
  schema_version: 3,
  name: "blazing red phoenix",
  noun: "phoenix",
  url: "https://gswiki.play.net/blazing_red_phoenix",
  picture: "",
  level: 90,
  family: "Elemental",
  type: "Avian",
  undead: false,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Element-based",
    "Magical"
  ],
  bcs: true,
  max_hp: 320,
  speed: nil,
  height: 6,
  size: "large",
  areas: [
    {
      name: "Volcanic Flats",
      uids: [3023107..3023123]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw (attack)",
        as: (330..390)
      },
      {
        name: "Bite (attack)",
        as: 380
      },
      {
        name: "Beak",
        as: 375
      },
      {
        name: "Beak of flame",
        as: 393
      },
      {
        name: "Flaming maw",
        as: 396
      },
      {
        name: "Lash",
        as: 402
      },
      {
        name: "Roaring ball of fire",
        as: 357
      },
      {
        name: "Sharp beak",
        as: 377
      },
      {
        name: "Stream of fire",
        as: 361
      }
    ],
    bolt_spells: [
      {
        name: "Major Fire (908)",
        as: 345
      }
    ],
    warding_spells: [
      {
        name: "Immolation (519)",
        cs: 377
      }
    ],
    offensive_spells: [
      {
        name: "Firestorm (1715)"
      },
      {
        name: "Major Elemental Wave (435)"
      }
    ],
    maneuvers: [
      {
        name: "Ethereal Wave"
      },
      {
        name: "Shield Bash"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (314..319),
    ranged: (234..330),
    bolt: (234..330),
    udf: 410,
    bar_td: nil,
    cle_td: (384..387),
    emp_td: (371..380),
    pal_td: (330..336),
    ran_td: (321..330),
    sor_td: (391..397),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 411,
    mjs_td: nil,
    mns_td: 368,
    mnm_td: (270..279),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "Flying",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a firewheel arrow fletched with plain white feathers"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Composed entirely of elemental flame, the majestic blazing red phoenix resembles a deadly bird of prey, with a short hooked beak, a compact muscular frame, wide wingspan, and sharp talons. Its unearthly form is a constant wreathing of elemental fire that is at once blinding as it is scalding."
    ],
    arrival: [
      "A blazing red phoenix flies in, surrounded in raging flames.",
      "A blazing red phoenix flies in on wobbly wings."
    ],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A blazing red phoenix gnashes at you with a flaming maw!",
        "A blazing red phoenix tries to spear you with {pronoun} beak of flame!",
        "Fiery talons lash out at you as a blazing red phoenix dives on your position!",
        "A blazing red phoenix rakes at you with a razor-sharp claw!",
        "A blazing red phoenix flaps {pronoun} wings of flame at you!"
      ],
      hurl: [
        "A blazing red phoenix hurls {weapon} at you!"
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
