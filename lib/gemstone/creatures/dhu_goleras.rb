{
  schema_version: 3,
  name: "dhu goleras",
  noun: "goleras",
  url: "https://gswiki.play.net/dhu_goleras",
  picture: "",
  level: 78,
  family: "Goleras",
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
    "Magical",
    "Boss"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: 5,
  size: "small",
  areas: [
    {
      name: "Maaghara Tower",
      uids: [13022004..13022055]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Dagger",
        as: (379..387)
      }
    ],
    bolt_spells: [
      {
        name: "Balefire (713)",
        as: 364
      }
    ],
    warding_spells: [
      {
        name: "Bind (214)",
        cs: 342
      },
      {
        name: "Blood Burst (701)",
        cs: 353
      },
      {
        name: "Calm (201)",
        cs: 342
      },
      {
        name: "Corrupt Essence (703)",
        cs: 353
      },
      {
        name: "Curse (715)",
        cs: 353
      },
      {
        name: "Dark Catalyst (719)",
        cs: 353
      },
      {
        name: "Disintegrate (705)",
        cs: 353
      },
      {
        name: "Limb Disruption (708)",
        cs: 353
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Energy Maelstrom (710)"
      },
      {
        name: "Quake (709)"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "10",
    immunities: [],
    melee: (338..395),
    ranged: (274..292),
    bolt: (274..292),
    udf: (360..433),
    bar_td: (302..314),
    cle_td: (312..336),
    emp_td: (325..331),
    pal_td: (276..288),
    ran_td: (282..291),
    sor_td: (329..350),
    wiz_td: 365,
    mje_td: (353..365),
    mne_td: (353..365),
    mjs_td: (307..331),
    mns_td: (307..331),
    mnm_td: (262..271),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bone-handled dagger"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "tiny golden seed",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    attacks: {
      attack: [
        "A dhu goleras swings {weapon} at you!",
        "A dhu goleras waves {pronoun} knobby grey fingers at you!"
      ],
      claw: [
        "A dhu goleras swipes at {pronoun} wide pus-filled eyes and claws hatefully at the air."
      ]
    },
    stand: [
      "A dhu goleras clambers to {pronoun} feet."
    ],
    description: [
      "Dull, mottled, grey skin covers the dhu goleras's stubby, wrinkled torso. The arms appear twice as long as they should be, ending in long, twig-like fingers. The legs are the opposite. Short and misshapen, they have three knees each, giving the dhu goleras a peculiar, hobbling gait, yet with incredible quickness. Huge, lidless, moon-shaped eyes with white irises bulge from a bony cranium atop a long, thin, rubbery neck. Green ichor drips from around the eyes, running down the sunken cheeks. The dhu goleras extends his long white tongue and licks off what ichor he can reach, consuming it with relish."
    ],
    arrival: [
      "A dhu goleras arrives with a loping, uneven gait, {pronoun} body rocking side-to-side and {pronoun} head and arms flopping wildly."
    ],
    flee: [
      "A dhu goleras moves off with a loping, uneven gait, {pronoun} body rocking side-to-side and {pronoun} head and arms flopping wildly as {pronoun} heads {direction}.",
      "A dhu goleras moves off with a loping, uneven gait emitting shrill cries of annoyance as {pronoun} heads {direction}."
    ],
    death: [
      "The dhu goleras opens {pronoun} mouth wide and lets out a choked, shrill scream and {pronoun} eyes cloud over to a solid milky white as {pronoun} collapses and dies.",
      "The dhu goleras opens {pronoun} mouth wide and lets out a choked, shrill scream and {pronoun} eyes cloud over to a solid milky white as {pronoun} dies.",
      "The dhu goleras opens {pronoun} mouth wide and lets out a choked, silent scream and {pronoun} eyes cloud over to a solid milky white as {pronoun} collapses and dies.",
      "The dhu goleras opens her mouth wide and lets out a choked, silent scream and her eyes cloud over to a solid milky white as she dies."
    ],
    decay: [
      "A dhu goleras's body decomposes into a foul, acidic liquid that rapidly evaporates."
    ],
    search: [],
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
