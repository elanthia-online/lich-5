{
  schema_version: 3,
  name: "hunch-backed dogmatist",
  noun: "dogmatist",
  url: "https://gswiki.play.net/hunch-backed_dogmatist",
  picture: "",
  level: 70,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: "miniboss",
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 238,
  speed: 14,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "Temple Wyneb",
      uids: [13300001..13300076, 13300080..13300080]
    },
    {
      name: "unmapped",
      uids: [13300077..13300079]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Kaskara",
        as: 350
      }
    ],
    bolt_spells: [
      {
        name: "Fire Spirit (111)",
        as: 356
      }
    ],
    warding_spells: [
      {
        name: "Mass Interference (217)",
        cs: 320
      },
      {
        name: "Fervent Reproach (312)",
        cs: 320
      },
      {
        name: "Censure (316)",
        cs: 320
      },
      {
        name: "Interdiction",
        cs: 320
      }
    ],
    offensive_spells: [
      {
        name: "Spirit Dispel (119)"
      }
    ],
    maneuvers: [],
    special_abilities: [
      {
        name: "Gaze"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "5N",
    immunities: [],
    melee: (331..378),
    ranged: (261..270),
    bolt: (261..270),
    udf: (354..463),
    bar_td: (268..277),
    cle_td: (281..397),
    emp_td: (283..293),
    pal_td: (247..257),
    ran_td: (247..256),
    sor_td: (315..322),
    wiz_td: (315..322),
    mje_td: (315..322),
    mne_td: (315..322),
    mjs_td: (277..293),
    mns_td: (277..293),
    mnm_td: (271..280),
    defensive_spells: [
      "Wall of Force (140)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "Resurrect",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a silver-edged black silk sack",
    "a tarnished invar kaskara"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Farlook vitreous humor",
      "vial of farlook vitreous humor",
      "radiant crimson mote of essence"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A hunch-backed dogmatist's frail frame has seen many years of toil and abuse. Evidence of such hardship appears in the stooped posture of the dogmatist. A defined hump protrudes from behind the dogmatist's head, easily discerned through layers of clothing and leather armor. The hunch-backed dogmatist's eyes glance frequently from side-to-side, as if constantly waiting for something to appear."
    ],
    arrival: [
      "A hunch-backed dogmatist trots in with {pronoun} hands clasped together!",
      "A hunch-backed dogmatist trots in with {pronoun} {weapon}!"
    ],
    flee: [
      "A hunch-backed dogmatist clasps {pronoun} hands together and trots east.",
      "A hunch-backed dogmatist clasps {pronoun} hands together and trots west."
    ],
    death: [],
    decay: [
      "A hunch-backed dogmatist crumbles in upon {reflexive}, {pronoun} skin flaking away as if {pronoun} only served as an outer shell."
    ],
    search: [],
    spell_prep: [
      "A hunch-backed dogmatist mutters a harsh rite."
    ],
    stand: [
      "The hunch-backed dogmatist rises to {pronoun} knees. \"Why hast ye forsaken me m'lady, served you well I did!\" beckons the dogmatist in a desperate prayer.",
      "The hunch-backed dogmatist rises to {pronoun} knees. \"Why hast ye forsaken me m'lord, served you well I did!\" beckons the dogmatist in a desperate prayer."
    ],
    attacks: {
      attack: [
        "A hunch-backed dogmatist nods {pronoun} head toward you!"
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
