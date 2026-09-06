{
  schema_version: 3,
  name: "triton warden",
  noun: "warden",
  url: "https://gswiki.play.net/triton_warden",
  picture: "",
  level: 102,
  family: "Triton",
  type: "Biped",
  undead: false,
  blood: nil,
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
  speed: 4,
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
        name: "Longbow"
      },
      {
        name: "Pale driftwood arrow",
        as: (431..456)
      },
      {
        name: "Sapphire-tipped arrow",
        as: (431..456)
      },
      {
        name: "Brackish green arrow",
        as: 446
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Wild Entropy (603)",
        cs: 448
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Sunburst (609)"
      },
      {
        name: "Tangleweed (610)"
      },
      {
        name: "Spike Thorn (616)"
      },
      {
        name: "Stealth"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (130..646),
    ranged: (259..422),
    bolt: (259..422),
    udf: (419..620),
    bar_td: nil,
    cle_td: (426..432),
    emp_td: (421..423),
    pal_td: (371..381),
    ran_td: (365..375),
    sor_td: (433..471),
    wiz_td: nil,
    mje_td: (401..481),
    mne_td: (401..481),
    mjs_td: (341..366),
    mns_td: (341..366),
    mnm_td: nil,
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)",
      "Natural Colors (601)",
      "Resist Elements (602)",
      "Self Control (613)",
      "Sneaking (617)",
      "Nature's Touch (625)",
      "Wall of Thorns (640)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a dried seaweed-wrapped longbow",
    "a mildewed rough leather quiver"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "curved black claw",
    other: [
      "ayanad crystal",
      "n'ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A faded coat of sun-bleached oilskin graces the muscular shoulders of a triton warden, the rusted ornamentations covered in grey-cast barnacles and dried kelp. His trident-branded knuckles are exposed through his desiccated leather gloves, the shreds of hide clinging tightly to his green-tinged forearms. The warden growls softly through his clenched teeth, the sharp protrusions biting down on a broken driftwood pipe."
    ],
    arrival: [
      "A triton warden just arrived.",
      "A triton warden slips into hiding."
    ],
    flee: [
      "A triton warden heads {direction}.",
      "A triton warden limps {direction}."
    ],
    death: [
      "The triton warden gurgles once and goes still, a wrathful look on {pronoun} face.",
      "The triton warden collapses, gurgling once with a wrathful look on {pronoun} face before expiring."
    ],
    decay: [
      "A triton warden's slick skin begins to rapidly desiccate and dissolve away, leaving nothing behind."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      hurl: [
        "A triton warden throws a drake greatsword at you!",
        "A triton warden throws a drake greataxe at you!"
      ],
      attack: [
        "A triton warden swings a drake greatsword at you!",
        "A triton warden swings an onyx-hafted black ora jeddart-axe at you!",
        "A triton warden places one hand on top of the other, crossing {pronoun} palms toward you!"
      ],
      fire: [
        "A triton warden fires {weapon} at you!",
        "A triton warden fires a brackish green arrow at {target}!",
        "A triton warden fires a silver-streaked arrow at {target}!",
        "A triton warden fires a sapphire-tipped arrow at {target}!",
        "A triton warden fires a pale driftwood arrow at {target}!"
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
