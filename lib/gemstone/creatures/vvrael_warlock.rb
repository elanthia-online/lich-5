{
  schema_version: 3,
  name: "Vvrael warlock",
  noun: "warlock",
  url: "https://gswiki.play.net/vvrael_warlock",
  picture: "",
  level: 84,
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
  max_hp: 240,
  speed: 7,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "The Rift",
      uids: [4567001..4567055, 4568001..4568055]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Whip",
        as: (356..401)
      },
      {
        name: "Ball of greenish-black flame",
        as: (459..466)
      },
      {
        name: "Midnight black longsword",
        as: 470
      }
    ],
    bolt_spells: [
      {
        name: "Balefire (713)",
        as: 379
      }
    ],
    warding_spells: [
      {
        name: "Corrupt Essence (703)",
        cs: 360
      },
      {
        name: "Curse (715)",
        cs: 360
      },
      {
        name: "Elemental Blast (409)",
        cs: 364
      },
      {
        name: "Evil Eye (717)",
        cs: 360
      },
      {
        name: "Dark Catalyst (719)",
        cs: 360
      },
      {
        name: "Torment (718)",
        cs: 360
      },
      {
        name: "Midnight black longsword",
        cs: 364
      },
      {
        name: "Midnight black spiked whip",
        cs: 360
      }
    ],
    offensive_spells: [
      {
        name: "Spirit Strike (117)"
      },
      {
        name: "Bravery (211)"
      },
      {
        name: "Elemental Dispel (417)"
      }
    ],
    maneuvers: [
      {
        name: "Gesture"
      },
      {
        name: "Pounce"
      },
      {
        name: "Wing Buffet"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "2",
    immunities: ["magic"],
    melee: (360..657),
    ranged: (301..335),
    bolt: (301..335),
    udf: (388..682),
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
      "Spirit Warding I (101)",
      "Spirit Warding II (107)",
      "Lesser Shroud (120)",
      "Wall of Force (140)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Elemental Barrier (430)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a midnight black longsword",
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
    other: "Radiant crimson essence shard",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The Vvrael warlock's figure is tall and thin, with stark proportions that call to mind sharp, unforgiving angles. His features are stoic, however the eyes held in that pale, rigidly handsome face are full of fury and malignant intent. The creature seems to move in slow motion, each gesture full of drama and elegance. But the appearance of languid grace is insubstantial. Experience soon dispells this illusion and reveals the true nature of this enemy, whose movements are both lightning quick and deadly."
    ],
    arrival: [
      "The air becomes deathly cold as a Vvrael warlock strides into view!",
      "A Vvrael warlock strides in!",
      "A flickering Vvrael warlock strides in!"
    ],
    flee: [
      "A Vvrael warlock strides {direction}."
    ],
    death: [
      "The Vvrael warlock writhes in black agony and dies.",
      "The Vvrael warlock crumples to the floor motionless.",
      "The Vvrael warlock crumples to the ground motionless.",
      "The Vvrael warlock wails with rage as he crumples to the ground!  A viscous black liquid sprays out from his severed right leg thrashing on the ground!",
      "The Vvrael warlock wails with rage as he crumples to the ground!  A viscous black liquid sprays out from his severed left leg thrashing on the ground!"
    ],
    decay: [],
    search: [
      "A Vvrael warlock looks around apprehensively."
    ],
    spell_prep: [],
    stun_break: [
      "A Vvrael warlock shakes with black rage, shaking off the forces controlling him!"
    ],
    attacks: {
      attack: [
        "A Vvrael warlock swings {weapon} at you!",
        "A Vvrael warlock swings a midnight black longsword at {target}!",
        "A Vvrael warlock swings a midnight black spiked whip at {target}!",
        "A Vvrael warlock leaps to {pronoun} feet!",
        "A Vvrael warlock focuses a wave of black anti-mana at you!"
      ],
      hurl: [
        "A Vvrael warlock hurls {weapon} at you!"
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
