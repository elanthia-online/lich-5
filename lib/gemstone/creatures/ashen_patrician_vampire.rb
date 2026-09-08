{
  schema_version: 3,
  name: "ashen patrician vampire",
  noun: "vampire",
  url: "https://gswiki.play.net/ashen_patrician_vampire",
  picture: "",
  level: 107,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  blood: nil,
  bones: nil,
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
  max_hp: 375,
  speed: 6,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Moonsedge",
      uids: [4577106..4577123, 4577201..4577214, 4577216..4577249]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Rapier",
        as: "566 to"
      },
      {
        name: "Charge",
        as: 530
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Blind",
        cs: 455
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Disarm Weapon"
      },
      {
        name: "Feint"
      },
      {
        name: "Pounce"
      }
    ],
    special_abilities: [
      {
        name: "Mstrike"
      },
      {
        name: "Cripple"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (427..567),
    ranged: (379..710),
    bolt: (379..710),
    udf: (498..727),
    bar_td: (503..507),
    cle_td: (486..492),
    emp_td: 488,
    pal_td: (470..476),
    ran_td: 521,
    sor_td: (503..527),
    wiz_td: nil,
    mje_td: (419..544),
    mne_td: (419..544),
    mjs_td: nil,
    mns_td: 492,
    mnm_td: nil,
    defensive_spells: [
      "Mindward (1208)",
      "Blink (1215)"
    ],
    defensive_abilities: [],
    special_defenses: [
      "Health regeneration"
    ]
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a swept-hilt veil iron rapier adorned with jewels"
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
      "petrified mammoth tusk"
    ],
    armaments: [
      "drake greatsword",
      "drake greataxe",
      "drake falchion"
    ],
    transmogs: nil
  },
  messaging: {
    description: [
      ""
    ],
    arrival: [
      "An ashen patrician vampire prowls in, deadly grace in every fluid step.  With a smirk that twists {pronoun} exquisite features, {pronoun} bares {pronoun} shining white fangs.",
      "An ashen patrician vampire strides in, moving like flowing water.",
      "An ashen patrician vampire just came through some vaulting grey stone doors.",
      "An ashen patrician vampire just came through a heavy steel portcullis."
    ],
    flee: [
      "An ashen patrician vampire just went through some vaulting grey stone doors.",
      "An ashen patrician vampire just went through a heavy steel portcullis."
    ],
    death: [],
    decay: [
      "Groans and cracks emanate from an infernal death knight's armor as it suddenly succumbs to metal fatigue.  Within seconds, his skeletal form collapses into blanched powder and blows away.",
      "Maggots and buzzing flies burst from a cadaverous tatterdemalion ghast's flesh as her skin peels and crumbles.  The scavenging insects rapidly consume the remains, leaving little but brittle bones."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "An ashen patrician vampire tears free from {pronoun} unnatural slumber with a hoarse gasp."
    ],
    attacks: {
      attack: [
        "An ashen patrician vampire swings {pronoun} {weapon} at your ghezyte long bow!",
        "An ashen patrician vampire swings {pronoun} {weapon} at your gleaming steel baselard!",
        "An ashen patrician vampire swings {pronoun} {weapon} at your smooth glowbark staff!",
        "An ashen patrician vampire swings {pronoun} {weapon} at your glowbark long bow!",
        "An ashen patrician vampire flicks a finger impatiently at you!",
        "An ashen patrician vampire turns, blade spinning in {pronoun} hand toward you!"
      ],
      bite: [
        "An ashen patrician vampire snaps {pronoun} fingers with an artful flourish!"
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
