{
  schema_version: 3,
  name: "Ithzir adept",
  noun: "adept",
  url: "https://gswiki.play.net/ithzir_adept",
  picture: "",
  level: 96,
  family: "Ithzir",
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
  boss_type: nil,
  otherclass: [
    "Living",
    "Extraplanar"
  ],
  bcs: true,
  max_hp: 240,
  speed: 6,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Old Ta'Faendryl",
      uids: [17001101..17001107, 17004001..17004028, 17004031..17004120, 17004160..17004168, 17004180..17004187, 17004190..17004195]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Quarterstaff",
        as: 408
      },
      {
        name: "Twisted crystal-tipped staff",
        as: (408..428)
      }
    ],
    bolt_spells: [
      {
        name: "Cone of Elements (518)",
        as: 379
      },
      {
        name: "Major Cold (907)",
        as: 379
      },
      {
        name: "Major Fire (908)",
        as: 379
      },
      {
        name: "Major Shock (910)",
        as: 379
      },
      {
        name: "Minor Acid (904)",
        as: 379
      },
      {
        name: "Minor Fire (906)",
        as: 379
      },
      {
        name: "Minor Water (903)",
        as: 379
      }
    ],
    warding_spells: [
      {
        name: "Weapon Fire (915)",
        cs: 402
      },
      {
        name: "Twisted crystal-tipped staff",
        cs: 402
      }
    ],
    offensive_spells: [
      {
        name: "Call Wind (912)"
      },
      {
        name: "Lightning mote"
      }
    ],
    maneuvers: [
      {
        name: "Palm Thrust"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6",
    immunities: [],
    melee: (364..605),
    ranged: (342..507),
    bolt: (342..507),
    udf: (506..579),
    bar_td: (379..391),
    cle_td: (391..409),
    emp_td: (397..405),
    pal_td: (348..351),
    ran_td: (353..356),
    sor_td: (411..436),
    wiz_td: nil,
    mje_td: (440..498),
    mne_td: (440..498),
    mjs_td: 420,
    mns_td: 420,
    mnm_td: (355..357),
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Elemental Barrier (430)",
      "Thurfel's Ward (503)",
      "Elemental Focus (513)",
      "Prismatic Guard (905)",
      "Mass Blur (911)",
      "Wizard Shield (919)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a curved crystal-edged blade",
    "a suit of trimmed leather",
    "a twisted crystal-tipped staff"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "tiny golden seed",
      "radiant crimson mote of essence"
    ],
    armaments: [
      "heavy crystal-capped maul"
    ],
    transmogs: nil
  },
  messaging: {
    stun_break: [
      "An Ithzir adept holds {pronoun} head as {pronoun} tries to regain {pronoun} bearings."
    ],
    attacks: {
      bolt: [
        "An Ithzir adept hurls a chunk of ice at {target}!",
        "An Ithzir adept hurls a large boulder at {target}!"
      ],
      attack: [
        "An Ithzir adept swings {weapon} at you!",
        "An Ithzir adept thrusts {pronoun} palms out to {pronoun} sides!",
        "An Ithzir adept swings a twisted crystal-tipped staff at {target}!",
        "An Ithzir adept thrusts both palms toward {target}!",
        "An Ithzir adept unleashes a bolt of churning air at you!",
        "The Ithzir adept points at you.",
        "The Ithzir adept cocks {pronoun} head at you."
      ],
      hurl: [
        "An Ithzir adept hurls a chunk of ice at {target}!",
        "An Ithzir adept hurls a large boulder at {target}!"
      ]
    },
    stand: [
      "An Ithzir adept stands up, an angry look on {pronoun} face.",
      "An Ithzir adept rises to {pronoun} feet, {pronoun} green eyes blazing!"
    ],
    description: [
      "The Ithzir adept carries a bearing of absolute confidence, his piercing, pupil-less green eyes shrewdly taking in his surroundings. The Ithzir adept is slightly taller than a human, and while his humanoid form is similar to scores of other races, the hairless, blue-skinned body is nonetheless alien in its appearance. The adept wears a crisply-cut, silvery-blue tunic with high shoulders and a deep vee-neck. Emblazoned on the right breast of the tunic is a single green eye."
    ],
    arrival: [
      "An Ithzir initiate strides in, {pronoun} hands clasped before {pronoun}.",
      "An Ithzir adept suddenly appears out of nowhere!",
      "An Ithzir adept staggers in, barely able to keep {pronoun} feet!"
    ],
    flee: [
      "An Ithzir adept walks {direction}.",
      "An Ithzir adept limps {direction}.",
      "An Ithzir adept withdraws, disengaging from {target}."
    ],
    death: [
      "The Ithzir adept vainly struggles to rise, then goes still.",
      "An Ithzir adept's body shimmers slightly, then fades from view like a dissipating phantom."
    ],
    decay: [
      "The crystal crumbles into a fine blue powder that sifts through the adept's fingers."
    ],
    search: [],
    spell_prep: [
      "An Ithzir adept closes {pronoun} eyes while incanting an alien phrase."
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
