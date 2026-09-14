{
  schema_version: 3,
  name: "ethereal triton psionicist",
  noun: "psionicist",
  url: "https://gswiki.play.net/ethereal_triton_psionicist",
  picture: "",
  level: 103,
  family: "Triton",
  type: "Biped",
  undead: true,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "non-corporeal undead",
    "Boss"
  ],
  bcs: true,
  max_hp: 238,
  speed: 8,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Atoll",
      uids: [7138201..7138218]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Unarmed combat",
        as: "390 UAF"
      }
    ],
    bolt_spells: [
      {
        name: "Telekinesis (1206)",
        as: 365
      },
      {
        name: "Astral Spear (1408)",
        as: 365
      }
    ],
    warding_spells: [
      {
        name: "Thought Lash (1210)",
        cs: 448
      },
      {
        name: "Vertigo (1219)",
        cs: 448
      },
      {
        name: "Mindwipe (1225)",
        cs: 448
      },
      {
        name: "Mana Burst (1414)",
        cs: 457
      },
      {
        name: "Jab",
        cs: 448
      },
      {
        name: "Lash",
        cs: 448
      },
      {
        name: "Claw Curse",
        cs: 460
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Claw Curse"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "11N",
    immunities: [],
    melee: (204..501),
    ranged: (240..408),
    bolt: (240..408),
    udf: (406..542),
    bar_td: nil,
    cle_td: 463,
    emp_td: (440..447),
    pal_td: 380,
    ran_td: 415,
    sor_td: (447..480),
    wiz_td: nil,
    mje_td: 404,
    mne_td: (485..498),
    mjs_td: (348..398),
    mns_td: (435..457),
    mnm_td: nil,
    defensive_spells: [
      "Empathic Focus (1109)",
      "Strength of Will (1119)",
      "Intensity (1130)",
      "Iron Skin (1202)",
      "Foresight (1204)",
      "Mindward (1208)",
      "Blink (1215)",
      "Premonition (1220)"
    ],
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
    other: [
      "ayanad crystal",
      "n'ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    attacks: {
      attack: [
        "The ethereal triton psionicist attempts to jab you!",
        "The ethereal triton psionicist attempts to punch you!",
        "An ethereal triton psionicist levitates a jagged piece of rock at you!",
        "An ethereal triton psionicist levitates a bundle of silver-streaked arrows at you!",
        "An ethereal triton psionicist levitates a bundle of brackish green arrows at you!",
        "An ethereal triton psionicist levitates a dried seaweed-wrapped longbow at you!",
        "An ethereal triton psionicist levitates some silver coins at you!",
        "An ethereal triton psionicist levitates a table leg at you!"
      ],
      creature_spell: [
        "An ethereal triton psionicist points a clawed finger toward {target}!"
      ]
    },
    stun_break: [
      "An ethereal triton psionicist looks around as if waking up from a dream.",
      "An ethereal triton psionicist flares briefly with a dull glow, rousing {reflexive} from slumber and righting {pronoun} posture.",
      "An ethereal triton psionicist flares briefly with a dull glow, rousing {reflexive} from slumber."
    ],
    description: [
      "An ethereal triton psionicist scowls about the area, her unsubstantial bluish skin rippling like waves across the ocean. Her tongue flickers out, pierced by a tiny atoll crab, and barnacles encircle each muscular arm. Sigil-carved shell rings adorn each finger, and a broken ivory trident dangles from an intangible coral belt."
    ],
    arrival: [
      "An ethereal triton psionicist just arrived."
    ],
    flee: [
      "An ethereal triton psionicist heads {direction}."
    ],
    death: [
      "The triton psionicist fades into transparency, her remnants rapidly dissolving into the air.",
      "An ethereal triton psionicist's dreamy gaze goes lifeless."
    ],
    decay: [],
    search: [
      "An ethereal triton psionicist glances around, sure that {pronoun} has missed something..."
    ],
    spell_prep: [
      "An ethereal triton psionicist chants in an incomprehensible language, causing streams of dim grey energy to lash about {pronoun} hands."
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
