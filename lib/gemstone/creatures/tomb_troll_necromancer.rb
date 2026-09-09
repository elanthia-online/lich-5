{
  schema_version: 3,
  name: "tomb troll necromancer",
  noun: "necromancer",
  url: "https://gswiki.play.net/tomb_troll_necromancer",
  picture: "",
  level: 54,
  family: "Troll",
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
  max_hp: 400,
  speed: nil,
  height: 9,
  size: "large",
  areas: [
    {
      name: "Marsh Keep",
      uids: [376063..376083]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Runestaff",
        as: (133..283)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Curse (715)",
        cs: 266
      },
      {
        name: "Limb Disruption (708)",
        cs: 266
      },
      {
        name: "Pain (711)",
        cs: 266
      },
      {
        name: "Blood Burst (701)",
        cs: 266
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Animate Dead (730)"
      },
      {
        name: "Point"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (246..362),
    ranged: (232..311),
    bolt: 203,
    udf: (263..397),
    bar_td: (212..242),
    cle_td: (259..269),
    emp_td: (257..267),
    pal_td: (238..247),
    ran_td: (207..213),
    sor_td: (252..285),
    wiz_td: nil,
    mje_td: 276,
    mne_td: 276,
    mjs_td: (230..237),
    mns_td: (230..237),
    mnm_td: (198..208),
    defensive_spells: [
      "Elemental Defense II (406)",
      "Fasthr's Reward (115)",
      "Mass Elemental Defense (419)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a slime-covered willow runestaff"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "troll eyeball",
    other: [
      "small troll tooth",
      "large troll tooth"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    stun_break: [
      "A tomb troll necromancer stumbles, nearly dropping to {pronoun} knees as {pronoun} tries to regain {pronoun} composure.",
      "A tomb troll necromancer tries to regain {pronoun} composure."
    ],
    attacks: {
      attack: [
        "A tomb troll necromancer swings {weapon} at you!",
        "A tomb troll necromancer exhales the last of a virulent green mist.",
        "A tomb troll necromancer exhales a virulent green mist toward you, but you are unaffected.",
        "A tomb troll necromancer points forcefully at you!"
      ],
      pestilence: [
        "A tomb troll necromancer exhales a virulent green mist toward {target}, instantly infecting {target}. {target} convulses violently!"
      ]
    },
    stand: [
      "A tomb troll necromancer rolls to {pronoun} feet, grinning wildly."
    ],
    description: [
      "Similar in appearance to the common tomb troll, the pale skinned necromancer shares the same patches of lanky yellow hair that sporadically cover his squat form. His oversize eyes are filled with a greater intelligence than his cousins', granting him comprehension of the darker arts of necromancy, and making the troll a terror with the magics in the realm of death. Around his wide, disgusting and oily waist, the necromancer wears a string of pouches intermingled with rotting digits of dead kinsmen."
    ],
    arrival: [
      "A tomb troll necromancer lopes into the room, sweeping {pronoun} head back and forth."
    ],
    flee: [
      "A tomb troll necromancer lopes {direction}.",
      "A tomb troll necromancer limps {direction}."
    ],
    death: [
      "A tomb troll necromancer glares forward, then collapses in a motionless heap."
    ],
    decay: [
      "A tomb troll necromancer decays into a pile of skin and bones."
    ],
    search: [],
    spell_prep: [
      "A tomb troll necromancer traces a sign that contorts in the air while {pronoun} forcefully incants a dark invocation."
    ],
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
