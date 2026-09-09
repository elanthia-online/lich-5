{
  schema_version: 3,
  name: "triton executioner",
  noun: "executioner",
  url: "https://gswiki.play.net/triton_executioner",
  picture: "",
  level: 96,
  family: "Triton",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 300,
  speed: 4,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Ruined Temple",
      uids: [3031025..3031042, 3031045..3031080]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Handaxe",
        as: (433..451)
      },
      {
        name: "Heavy crossbow"
      },
      {
        name: "longsword",
        as: (433..453)
      },
      {
        name: "Streaked pale driftwood bolt",
        as: (433..453)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Coup de Grace"
      },
      {
        name: "Cutthroat"
      },
      {
        name: "Drown"
      },
      {
        name: "Sweep"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (325..528),
    ranged: (266..463),
    bolt: (266..463),
    udf: (498..555),
    bar_td: 340,
    cle_td: 379,
    emp_td: (359..371),
    pal_td: (312..321),
    ran_td: (303..312),
    sor_td: (381..396),
    wiz_td: nil,
    mje_td: (393..411),
    mne_td: (393..411),
    mjs_td: 371,
    mns_td: 371,
    mnm_td: (294..303),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a coral-hilted sharply tapered longsword",
    "a crested thick leather harness",
    "a navy-banded slate grey targe",
    "a rough ashen heavy crossbow",
    "a sharply curved black handaxe",
    "a short-prodded heavy arbalest",
    "a silver-rimmed black steel buckler",
    "a teardrop-clasped dark leather harness"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "ayanad crystal",
      "n'ayanad crystal",
      "tiny golden seed",
      "radiant crimson essence shard"
    ],
    armaments: [
      "black ora jeddart-axe",
      "drake greatsword",
      "drake greataxe",
      "drake falchion",
      "corroded black ora awl-pike"
    ],
    transmogs: nil
  },
  messaging: {
    description: [
      "The triton executioner scans his surroundings with merciless eyes as if seeking his next client. Heavy, leathery lips are pulled into a perpetually disgusted sneer, pinching the creature's nostrils into narrow slits. Animal muscles, powerfully knotted beneath his moist blue-green skin, seem ready to spring in any direction. The executioner wears a dark blue tabard emblazoned with a silver wave upon the chest."
    ],
    arrival: [
      "A triton executioner stalks in silently, {pronoun} cold eyes gleaming with hatred.",
      "A triton executioner strides in, a wary look on {pronoun} face.",
      "A triton executioner strides in, gliding swiftly through the water with a wary look on his face.",
      "A triton executioner just arrived.",
      "A triton executioner slips into hiding."
    ],
    flee: [
      "A triton executioner hurtles {reflexive} at you with great speed, but flies slightly off center of {pronoun} target and tumbles to the water with a splash!"
    ],
    death: [
      "The triton executioner gurgles once and goes still, a wrathful look on {pronoun} face.",
      "The triton executioner collapses to the floor with a splash, gurgling once with a wrathful look on {pronoun} face before expiring.",
      "The triton executioner collapses, gurgling once with a wrathful look on {pronoun} face before expiring."
    ],
    decay: [
      "A triton executioner's slick skin begins to rapidly desiccate and dissolve away, leaving nothing behind."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      cutthroat: [
        "A triton executioner springs upon you from behind and attempts to slit your throat!"
      ],
      attack: [
        "A triton executioner swings {weapon} at you!",
        "A triton executioner leaps from hiding to attack!",
        "A triton executioner thrusts with a corroded bronze scaling fork at you!"
      ],
      fire: [
        "A triton executioner fires {weapon} at you!"
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
