{
  schema_version: 3,
  name: "nedum vereri",
  noun: "vereri",
  url: "https://gswiki.play.net/nedum_vereri",
  picture: "",
  level: 18,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: nil,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 160,
  speed: 8,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Temple of Love",
      uids: [2155012..2155044, 2155046..2155048]
    },
    {
      name: "Abbey",
      uids: [4132101..4132118]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Morning star",
        as: 161
      },
      {
        name: "Gilt-thorned steel spikestar",
        as: 120
      },
      {
        name: "Claw",
        as: 141
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Calm (201)",
        cs: 95
      },
      {
        name: "Repel (Fear)",
        cs: 95
      },
      {
        name: "Gilt-thorned steel spikestar",
        cs: 95
      },
      {
        name: "Morning star",
        cs: 95
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [],
    melee: (141..170),
    ranged: (77..107),
    bolt: (77..107),
    udf: (153..168),
    bar_td: nil,
    cle_td: 54,
    emp_td: 54,
    pal_td: (51..54),
    ran_td: 54,
    sor_td: 54,
    wiz_td: nil,
    mje_td: 54,
    mne_td: 54,
    mjs_td: (51..54),
    mns_td: (51..54),
    mnm_td: 54,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a gilt-thorned steel spikestar",
    "an age-blanched raw silk shift patterned with faded red roses"
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
      "Once a priestess, this woman's service to her deity has ended tragically with her binding to life after death. Tattered robes hang from her form, and although she is lovely in spite of her glowing eyes, you cannot look upon her for long without feeling that you might run from her in fear."
    ],
    arrival: [
      "A nedum vereri just arrived.",
      "A nedum vereri just arrived from the altar.",
      "A nedum vereri just arrived from the sanctuary.",
      "A nedum vereri just came through a pair of double doors."
    ],
    flee: [
      "A nedum vereri heads {direction}.",
      "A nedum vereri just went through a pair of double doors."
    ],
    death: [
      "A nedum vereri exhales a sigh of relief and slumps to the ground motionless.",
      "A nedum vereri exhales a sigh of relief and goes still."
    ],
    decay: [
      "A nedum vereri fades away."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A nedum vereri swings {weapon} at you!",
        "A nedum vereri exhales a sigh of relief and slumps to the ground motionless.",
        "A nedum vereri exhales a sigh of relief and goes still.",
        "A nedum vereri leaps to {pronoun} feet."
      ],
      claw: [
        "A nedum vereri claws at you!"
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
