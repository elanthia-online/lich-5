{
  schema_version: 3,
  name: "seething pestilent vision",
  noun: "vision",
  url: "https://gswiki.play.net/seething_pestilent_vision",
  picture: "",
  level: 70,
  family: "Humanoid",
  type: "",
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
  speed: nil,
  height: 10,
  size: "medium",
  areas: [
    {
      name: "Abbey",
      uids: [4132201..4132240, 4132243..4132248]
    },
    {
      name: "unmapped",
      uids: [4132241..4132242]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Disintegrate (705)"
      },
      {
        name: "Corrupt Essence (703)"
      },
      {
        name: "Claw",
        as: 330
      }
    ],
    offensive_spells: [
      {
        name: "Web (118)"
      },
      {
        name: "Spirit Dispel (119)"
      }
    ],
    maneuvers: [
      {
        name: "Gesture"
      },
      {
        name: "Vile Energy"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (227..395),
    ranged: (234..279),
    bolt: (234..279),
    udf: (299..401),
    bar_td: nil,
    cle_td: (287..297),
    emp_td: (295..305),
    pal_td: (259..269),
    ran_td: (266..269),
    sor_td: nil,
    wiz_td: nil,
    mje_td: 329,
    mne_td: 329,
    mjs_td: (252..306),
    mns_td: (252..306),
    mnm_td: (216..226),
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
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Writhing green smoke comprises the form of a seething pestilent vision. It has only the suggestion of a humanoid form, and a buzzing like that of countless swarming flies fills the air around it. Where eyes ought to be, it has only a pair of luminous orbs that pulse between phosphorescent white and toxic green."
    ],
    arrival: [
      "A seething pestilent vision just arrived from some lichen-clad dark wooden docks.",
      "A seething pestilent vision just arrived from a torchlit overgrown grotto.",
      "A seething pestilent vision just came through a sculpted stone arch.",
      "A seething pestilent vision just came through a pair of inlaid bronze doors."
    ],
    flee: [
      "A seething pestilent vision just went to some lichen-clad dark wooden docks.",
      "A seething pestilent vision just went through a pair of inlaid bronze doors.",
      "A seething pestilent vision just went up a warped oaken gangplank.",
      "A seething pestilent vision just went through a sculpted stone arch.",
      "A seething pestilent vision just went across a vine-covered wood suspension bridge.",
      "A seething pestilent vision just went to a torchlit overgrown grotto.",
      "A seething pestilent vision just went down a warped oaken gangplank."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A seething pestilent vision directs the flow of {pronoun} vile energies toward you!",
        "A seething pestilent vision exhales the last of a virulent green mist.",
        "A seething pestilent vision exhales a virulent green mist toward you, but you are unaffected."
      ],
      claw: [
        "A seething pestilent vision claws at you!"
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
