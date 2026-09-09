{
  schema_version: 3,
  name: "siren",
  noun: "siren",
  url: "https://gswiki.play.net/siren",
  picture: "",
  level: 96,
  family: "Fey",
  type: "Hybrid",
  undead: false,
  blood: true,
  bones: true,
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
  max_hp: 238,
  speed: nil,
  height: 5,
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
        name: "Ensnare",
        as: (446..449)
      },
      {
        name: "Coral-hilted sharply tapered longsword",
        as: 428
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Corrupt Essence (703)",
        cs: 402
      },
      {
        name: "Holding Song (1001)",
        cs: 402
      },
      {
        name: "Lullabye (1005)",
        cs: 402
      },
      {
        name: "Song of Depression (1015)",
        cs: 402
      },
      {
        name: "Song of Unravelling (1013)",
        cs: 402
      },
      {
        name: "Coral-hilted sharply tapered longsword",
        cs: 410
      },
      {
        name: "Ensnare",
        cs: 416
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1",
    immunities: [],
    melee: (408..577),
    ranged: (413..572),
    bolt: (336..572),
    udf: (542..619),
    bar_td: 363,
    cle_td: (389..391),
    emp_td: (391..424),
    pal_td: (336..344),
    ran_td: (317..324),
    sor_td: (398..407),
    wiz_td: nil,
    mje_td: (403..435),
    mne_td: (403..435),
    mjs_td: (391..400),
    mns_td: (391..400),
    mnm_td: (302..310),
    defensive_spells: [
      "Elemental Defense I",
      "Elemental Defense II",
      "Elemental Defense III",
      "Song of Mirrors",
      "Song of Tonis"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a pearlescent oyster shell shield",
    "a sienna-banded scallop shell shield",
    "an oak-shafted silvery blue trident"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "pristine siren's hair",
      "ayanad crystal",
      "n'ayanad crystal",
      "tiny golden seed",
      "radiant crimson essence shard"
    ],
    armaments: [
      "feras dagger",
      "feras falchion",
      "feras rapier",
      "drake scimitar",
      "feras mattock",
      "feras tiger-claw",
      "feras hammer",
      "drake falchion",
      "feras mace",
      "drake yierka-spur",
      "drake dagger",
      "black ora jeddart-axe",
      "drake greataxe",
      "drake greatsword",
      "faenor-tipped black ora broadsword",
      "drake mace",
      "black ora pilum"
    ],
    transmogs: nil
  },
  messaging: {
    description: [
      "The siren is a peculiar vision of beauty from the sea. Though her lower body is that of an iridescently scaled fish, it takes away nothing from the rest of her ravishingly feminine figure draped in long, golden blonde hair and surrounded by a mystical aura. Discretely hidden webbing beneath her arms that aids in navigating deep waters has given rise to the erroneous legend that the siren can also fly. The soothing song from these strangely beautiful creatures has pulled many sailors to their deaths, and every moment that the siren gazes at you with her captivating brilliant blue eyes and serenades you with liquid notes from her glistening full lips is a moment that you plunge deeper into danger yourself."
    ],
    arrival: [
      "A siren arrives, warbling softly.",
      "A siren just arrived.",
      "A siren just came through a crumbling arch."
    ],
    flee: [
      "A siren just went up a spiral staircase.",
      "A siren just went down some descending stairs.",
      "A siren just went down a carved marble staircase leading to the submerged dais."
    ],
    death: [
      "The siren gives a plaintive wail before she slumps to her side and dies."
    ],
    decay: [
      "A siren decays into compost.",
      "The siren's soft aura fades and her flesh crumbles to reveal the corpse of a hideous scaled creature, which then quickly decays away.",
      "A deft siren decays into compost.",
      "A sickly green siren decays into compost."
    ],
    search: [],
    spell_prep: [
      "A siren chants hypnotically, swaying {pronoun} body in rhythm!"
    ],
    attacks: {
      attack: [
        "A siren swings {weapon} at you!",
        "A siren tries to ensnare you!",
        "A siren gazes upon you lovingly and blows a soft kiss toward you."
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
