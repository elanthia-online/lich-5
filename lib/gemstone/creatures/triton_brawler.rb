{
  schema_version: 3,
  name: "triton brawler",
  noun: "brawler",
  url: "https://gswiki.play.net/triton_brawler",
  picture: "",
  level: 98,
  family: "Triton",
  type: "Biped",
  undead: false,
  blood: true,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: 3,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Atoll",
      uids: [7138101..7138119]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "UCS",
        as: "414 UAF"
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Crowd Press"
      },
      {
        name: "Haymaker"
      },
      {
        name: "Headbutt"
      },
      {
        name: "Sucker Punch"
      },
      {
        name: "Twin Hammerfists"
      },
      {
        name: "Charge"
      },
      {
        name: "Fist"
      },
      {
        name: "Grapple"
      },
      {
        name: "Jab"
      },
      {
        name: "Kick"
      },
      {
        name: "Punch"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "11N",
    immunities: [],
    melee: (249..609),
    ranged: (109..502),
    bolt: (109..502),
    udf: (457..759),
    bar_td: 385,
    cle_td: (403..427),
    emp_td: (412..422),
    pal_td: (343..350),
    ran_td: (340..350),
    sor_td: (410..450),
    wiz_td: nil,
    mje_td: (427..460),
    mne_td: (427..460),
    mjs_td: (403..413),
    mns_td: (403..413),
    mnm_td: 419,
    defensive_spells: [
      "Iron Skin (1202)",
      "Mindward (1208)",
      "Brace (1214)",
      "Premonition (1220)"
    ],
    defensive_abilities: [],
    special_defenses: [
      "Slippery Mind"
    ]
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
    skin: "darkened triton hide",
    other: [
      "ayanad crystal",
      "n'ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    ambient: [
      "A triton brawler's expression briefly shifts, nearly but not quite smoothing into blankness.",
      "A triton brawler is surrounded by an ominous, chitinous clicking!"
    ],
    attacks: {
      attack: [
        "A triton brawler slams {pronoun} head into you!",
        "The triton brawler attempts to kick {target}!",
        "The triton brawler attempts to jab you!",
        "A triton brawler charges towards {target} and attempts to headbutt {pronoun}!",
        "A triton brawler swings a fist at {target}!",
        "The triton brawler attempts to punch {target}!",
        "A triton brawler slams {pronoun} head into {target}!",
        "The triton brawler attempts to grapple {target}!",
        "The triton brawler slams into {target}, who is sent careening headlong into a nearby group of combatants as {pronoun} falls to the ground!",
        "The triton brawler slams into {target}, who is sent careening into {target} as {pronoun} falls to the ground!",
        "The triton brawler slams into you, and you are sent careening headlong into a nearby group of combatants as you fall to the ground!",
        "The triton brawler slams into you, and you are sent careening into {target} as you fall to the ground!"
      ]
    },
    stun_break: [
      "A triton brawler looks around as if waking up from a dream."
    ],
    description: [
      "Wearing only a linen and leather pteruges, a triton brawler is covered in roughly inked black tattoos, a cavalcade of runes, sigils, and symbols twining about one another and obscuring his grey-blue flesh. Across his amphibian-like head is a tattoo of a powerful tentacle crushing a trident in its suckered grip. The brawler's eyes dart warily this way and that, and his tongue flicks in and out with deceptive laziness."
    ],
    arrival: [
      "A triton brawler just arrived.",
      "A triton brawler just arrived, limping badly.",
      "A tough triton brawler just arrived, limping badly.",
      "A triton brawler just arrived, limping.",
      "A triton brawler charges briskly into the area!",
      "A triton brawler just arrived, crawling along the ground."
    ],
    flee: [
      "A triton brawler heads {direction}."
    ],
    death: [
      "The triton brawler gurgles once and goes still, a wrathful look on {pronoun} face.",
      "A triton brawler's dreamy gaze goes lifeless.",
      "A triton brawler slumps slowly, {pronoun} skin growing darker from lack of air.",
      "A triton brawler's eyes roll up into {pronoun} head as {pronoun} body goes limp on the ground.",
      "The triton brawler collapses, gurgling once with a wrathful look on {pronoun} face before expiring."
    ],
    decay: [
      "A triton brawler's slick skin begins to rapidly desiccate and dissolve away, leaving nothing behind."
    ],
    search: [
      "A triton brawler glances around, sure that {pronoun} has missed something..."
    ],
    spell_prep: [],
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
