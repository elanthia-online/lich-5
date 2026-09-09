{
  schema_version: 3,
  name: "triton combatant",
  noun: "combatant",
  url: "https://gswiki.play.net/triton_combatant",
  picture: "",
  level: 98,
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
  max_hp: 300,
  speed: 6,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Ruined Temple",
      uids: [3031036..3031042, 3031056..3031106]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 414
      },
      {
        name: "Trident",
        as: (424..444)
      },
      {
        name: "Seaweed-wound rusted steel hatchet",
        as: (424..426)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Charge"
      },
      {
        name: "Disarm Weapon"
      },
      {
        name: "Feint"
      },
      {
        name: "Tackle"
      },
      {
        name: "Triton's Horn"
      },
      {
        name: "Drowning Pool"
      },
      {
        name: "Disarm"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "20",
    immunities: [],
    melee: (248..375),
    ranged: (137..418),
    bolt: (137..418),
    udf: (526..539),
    bar_td: 324,
    cle_td: (351..360),
    emp_td: (349..358),
    pal_td: (301..330),
    ran_td: (295..304),
    sor_td: (369..384),
    wiz_td: nil,
    mje_td: (375..399),
    mne_td: (375..399),
    mjs_td: 391,
    mns_td: 391,
    mnm_td: (294..303),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a reinforced canvas bandolier",
    "an elliptical brine-stained parma",
    "an oak-shafted silvery blue trident",
    "a razor-tined pale green trident"
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
      "tiny golden seed",
      "radiant crimson essence shard"
    ],
    armaments: [
      "drake greataxe",
      "drake greatsword",
      "corroded black ora awl-pike"
    ],
    transmogs: nil
  },
  messaging: {
    description: [
      "The triton combatant stands hunched, her head thrust forward, and neck enveloped by heavy, muscled shoulders. Tiny alien eyes stare from a prominently bony brow, regarding the world with stubborn truculence. A mottled brown ridge rises from the amphibian's forehead and sweeps up and back, hugging her skull. This heavy protuberance, covered with damp, leathery skin, provides her with formidable head and neck protection."
    ],
    arrival: [
      "A triton combatant strides in, a wary look on {pronoun} face.",
      "A triton combatant strides in, gliding swiftly through the water with a wary look on {pronoun} face.",
      "A triton combatant just arrived.",
      "A triton combatant charges briskly into the area, casting wide ripples in {pronoun} wake!",
      "A triton combatant charges briskly into the area!"
    ],
    flee: [
      "A triton combatant just went up some short ascending stairs.",
      "A triton combatant just went through a crumbling arch.",
      "A triton combatant hurtles {reflexive} at you with great speed, but flies slightly off center of {pronoun} target and tumbles to the water with a splash!",
      "A triton combatant sweeps {pronoun} pale green trident out in an arc behind {pronoun}, {pronoun} eyes darting around as if seeking out {pronoun} next opponent.",
      "A triton combatant sweeps {pronoun} rusted steel hatchet out in an arc behind {pronoun}, {pronoun} eyes darting around as if seeking out {pronoun} next opponent."
    ],
    death: [
      "The triton combatant gurgles once and goes still, a wrathful look on {pronoun} face.",
      "The triton combatant collapses to the floor with a splash, gurgling once with a wrathful look on {pronoun} face before expiring.",
      "The triton combatant collapses to the ground with a splash, gurgling once with a wrathful look on {pronoun} face before expiring.",
      "The triton combatant collapses, gurgling once with a wrathful look on {pronoun} face before expiring."
    ],
    decay: [
      "A triton combatant's slick skin begins to rapidly desiccate and dissolve away, leaving nothing behind."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A triton combatant swings {weapon} at you!",
        "A triton combatant thrusts with an oak-shafted silvery blue trident at you!",
        "A triton combatant thrusts with a razor-tined pale green trident at you!",
        "The triton combatant slams into you, and you are sent careening to the ground!",
        "A triton combatant swings {pronoun} {weapon} at your vultite bastard sword!",
        "A triton combatant swings {pronoun} {weapon} at your smooth glowbark staff!"
      ],
      charge: [
        "A triton combatant rushes forward at you with {pronoun} pale green trident and attempts a charge!",
        "A triton combatant rushes forward at you with {pronoun} silvery blue trident and attempts a charge!"
      ],
      hurl: [
        "A triton combatant throws {weapon} at you!"
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
