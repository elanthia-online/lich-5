{
  schema_version: 3,
  name: "Vvrael witch",
  noun: "witch",
  url: "https://gswiki.play.net/vvrael_witch",
  picture: "",
  level: 80,
  family: "Vvrael",
  type: "Biped",
  undead: false,
  blood: false,
  bones: false,
  limbs: true,
  witherable: false,
  sympathy: false,
  muggable: true,
  sleepable: false,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Extraplanar",
    "Anti-mana",
    "Boss"
  ],
  bcs: true,
  max_hp: 250,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "The Rift",
      uids: [4566001..4566055]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Minor Acid (904)"
      },
      {
        name: "Chunk of ice",
        as: 349
      },
      {
        name: "Large boulder",
        as: (314..349)
      },
      {
        name: "Midnight black morning star",
        as: (323..355)
      },
      {
        name: "Powerful lightning bolt",
        as: (314..360)
      },
      {
        name: "Stream of fire",
        as: 349
      },
      {
        name: "Midnight black curved dagger",
        as: 374
      },
      {
        name: "Midnight black spiked whip",
        as: 362
      }
    ],
    warding_spells: [
      {
        name: "Earthen Fury (917)"
      },
      {
        name: "Elemental Dispel (417)"
      },
      {
        name: "Midnight black morning star",
        cs: 352
      }
    ],
    maneuvers: [
      {
        name: "Anti-mana Wave"
      },
      {
        name: "Lash"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: ["magic"],
    melee: (366..602),
    ranged: (449..540),
    bolt: (449..540),
    udf: (517..644),
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Elemental Targeting (425)",
      "Elemental Barrier (430)",
      "Elemental Bias (508)",
      "Elemental Focus (513)",
      "Mass Blur (911)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a midnight black curved dagger",
    "a midnight black morning star",
    "a midnight black ora choker",
    "a midnight black spiked whip",
    "a midnight black tower shield",
    "some flowing midnight-black robes"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Radiant crimson essence shardTiny golden seed",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The Vvrael witch rises from the ground in a pillar of shadow, tall and slim, the outline of her perfect form frayed by a strange atmospheric disturbance. Her face is a vision of beauty. However, darkness fills her features like a secret biding in her glance, lending her visage an indistinct appearance. Her eyes are dark and wide, framed with fringes of long lashes, and in the depths of those expressive wells there flickers highlights of energy. Or perhaps they are coals of hatred waiting to be unearthed. The witch's hands move constantly, her long fingers and elegant nails making constant motions as if they have manic agendas of their own."
    ],
    arrival: [],
    flee: [
      "A Vvrael witch glides {direction}.",
      "A Vvrael witch withdraws, disengaging from {target}."
    ],
    death: [
      "The Vvrael witch writhes in black agony and dies.",
      "The Vvrael witch wails with rage as she crumples to the ground!  A viscous black liquid sprays out from her severed left leg thrashing on the ground!",
      "The Vvrael witch crumples to the ground motionless.",
      "The Vvrael witch wails with rage as she crumples to the ground!  A viscous black liquid sprays out from her severed right leg thrashing on the ground!",
      "The Vvrael witch crumples to the floor motionless."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A Vvrael witch whispers with an ominously soft voice.",
      "A Vvrael witch gestures gracefully, hurling ebon motes of anti-mana at you!"
    ],
    stun_break: [
      "A Vvrael witch shakes with black rage, shaking off the forces controlling {pronoun}!",
      "A Vvrael witch shrugs off the magic!"
    ],
    attacks: {
      attack: [
        "A Vvrael witch gestures gracefully, hurling ebon motes of anti-mana at you!",
        "A Vvrael witch swings {weapon} at you!",
        "A Vvrael witch throws {pronoun} head back, revelling in the anti-essence that flashes around {pronoun}, absorbing the magic!",
        "A Vvrael witch swings a midnight black spiked whip at {target}!",
        "A Vvrael witch swings a midnight black morning star at {target}!",
        "A Vvrael witch points a slender pale finger at you, beckoning you closer, a seductive smile playing across {pronoun} lips.",
        "A Vvrael witch leaps to {pronoun} feet!"
      ],
      bolt: [
        "A Vvrael witch hurls a stream of fire at {target}!",
        "A Vvrael witch hurls a chunk of ice at {target}!",
        "A Vvrael witch hurls a large boulder at {target}!",
        "A Vvrael witch hurls a powerful lightning bolt at {target}!"
      ],
      hurl: [
        "A Vvrael witch hurls {weapon} at you!",
        "A Vvrael witch hurls a chunk of ice at {target}!",
        "A Vvrael witch hurls a large boulder at {target}!"
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
