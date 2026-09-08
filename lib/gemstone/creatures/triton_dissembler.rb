{
  schema_version: 3,
  name: "triton dissembler",
  noun: "dissembler",
  url: "https://gswiki.play.net/triton_dissembler",
  picture: "",
  level: 94,
  family: "Triton",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 238,
  speed: 9,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Ruined Temple",
      uids: [3031025..3031035, 3031045..3031055]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Empathic Assault (1110)",
        as: 404
      },
      {
        name: "Fine-grained deep cerulean runestaff",
        as: 391
      }
    ],
    warding_spells: [
      {
        name: "Disintegrate (705)",
        cs: (382..409)
      }
    ],
    offensive_spells: [
      {
        name: "Implosion (720)"
      }
    ],
    maneuvers: [
      {
        name: "Fear Gaze"
      },
      {
        name: "Golden Nail"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: 291,
    ranged: (307..419),
    bolt: (307..419),
    udf: 470,
    bar_td: nil,
    cle_td: 388,
    emp_td: 380,
    pal_td: (334..337),
    ran_td: 327,
    sor_td: (378..385),
    wiz_td: nil,
    mje_td: (415..524),
    mne_td: (415..524),
    mjs_td: 433,
    mns_td: 433,
    mnm_td: (316..323),
    defensive_spells: [
      "Cloak of Shadows (712)",
      "Fasthr's Reward (115)",
      "Spirit Defense (103)",
      "Spirit Warding I (101)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a fine-grained deep cerulean runestaff"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a curved gold-flecked claw",
    other: [
      "ayanad crystal",
      "tiny golden seed",
      "n'ayanad crystal",
      "radiant crimson essence shard"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Weight carefully balanced upon her massive tail, the triton dissembler walks rigidly upright, moving with self-absorbed elegance. Luminous dark blue eyes are set deeply in the sockets of her fine-boned head where delicate, fleshy lips curve into an unpleasant smile. The dissembler's long, translucently webbed hands bear curved claws, carefully filed to tapered points and painted with gold lacquer. This pretense to arrogant refinement belies the feverishly clammy sweat covering the creature's slick, sea green hide."
    ],
    arrival: [
      "A triton dissembler arrives, striding forth with {pronoun} robes trailing behind {pronoun}.",
      "A triton dissembler strides in, a wary look on {pronoun} face.",
      "A triton dissembler strides in, gliding swiftly through the water with a wary look on her face.",
      "A triton dissembler just arrived."
    ],
    flee: [
      "A triton dissembler just went down some descending stairs.",
      "A triton dissembler just went down a carved marble staircase leading to the submerged dais."
    ],
    death: [
      "The triton dissembler gurgles once and goes still, a wrathful look on {pronoun} face.",
      "The triton dissembler collapses to the floor with a splash, gurgling once with a wrathful look on {pronoun} face before expiring."
    ],
    decay: [
      "The siren's soft aura fades and her flesh crumbles to reveal the corpse of a hideous scaled creature, which then quickly decays away."
    ],
    search: [],
    spell_prep: [
      "A triton dissembler chants in an incomprehensible language, causing streams of dim grey energy to lash about {pronoun} golden claws.",
      "A triton dissembler concentrates intently on you, and a pulse of pearlescent energy ripples toward you!",
      "A triton dissembler closes {pronoun} eyes in deep concentration..."
    ],
    attacks: {
      attack: [
        "A triton dissembler swings {weapon} at you!"
      ],
      bolt: [
        "A triton dissembler hurls a radiant ball of energy at you!"
      ],
      creature_spell: [
        "A triton dissembler points a single golden nail toward {target}!"
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
