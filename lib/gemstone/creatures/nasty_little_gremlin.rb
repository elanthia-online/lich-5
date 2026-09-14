{
  schema_version: 3,
  name: "nasty little gremlin",
  noun: "",
  url: "https://gswiki.play.net/nasty_little_gremlin",
  picture: "",
  level: 5,
  family: "Gremlin",
  type: "Biped",
  undead: false,
  blood: true,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 80,
  speed: nil,
  height: 3,
  size: "small",
  areas: [
    {
      name: "Wehntoph",
      uids: [484001..484013]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Dagger",
        as: 100
      },
      {
        name: "Unknown",
        as: 100
      },
      {
        name: "Nip",
        as: 80
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (22..91),
    ranged: (15..30),
    bolt: (15..30),
    udf: 96,
    bar_td: 10,
    cle_td: 10,
    emp_td: 10,
    pal_td: (7..10),
    ran_td: 10,
    sor_td: (10..11),
    wiz_td: nil,
    mje_td: 10,
    mne_td: 10,
    mjs_td: (3..10),
    mns_td: (3..10),
    mnm_td: 10,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a dagger",
    "a large blue sack",
    "a large orange sack",
    "a large yellow sack"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The little gremlin is a small furless creature with beady little eyes and sharp teeth that have been filed into triangular fangs. It has long, metal capped, nails protruding several inches from the tip of each finger. Though humanoid in form, it has a natural facial expression that is as wicked as any other known to nature."
    ],
    arrival: [],
    flee: [
      "A nasty little blue gremlin scampers {direction}.",
      "A nasty little red gremlin scampers {direction}.",
      "A nasty little green gremlin scampers {direction}.",
      "A nasty little orange gremlin scampers {direction}.",
      "A nasty little yellow gremlin scampers {direction}.",
      "A nasty little black gremlin scampers {direction}."
    ],
    death: [
      "The green gremlin falls to the ground and dies with a gentle sigh.",
      "The red gremlin falls to the ground and dies with a gentle sigh.",
      "The red gremlin sighs one last time and dies.",
      "The yellow gremlin falls to the ground and dies with a gentle sigh.",
      "The green gremlin sighs one last time and dies.",
      "The blue gremlin falls to the ground and dies with a gentle sigh.",
      "The black gremlin falls to the ground and dies with a gentle sigh.",
      "The orange gremlin falls to the ground and dies with a gentle sigh.",
      "The black gremlin sighs one last time and dies.",
      "The yellow gremlin sighs one last time and dies.",
      "The orange gremlin sighs one last time and dies."
    ],
    decay: [
      "A nasty little green gremlin decays into compost.",
      "A nasty little red gremlin decays into compost.",
      "A nasty little yellow gremlin decays into compost.",
      "A nasty little blue gremlin decays into compost.",
      "A nasty little black gremlin decays into compost.",
      "A nasty little orange gremlin decays into compost.",
      "A small, green cloud of smelly gas rises from the body of a big ugly kobold as {pronoun} decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A nasty little gremlin swings {weapon} at you!",
        "A nasty little gremlin nips at you!"
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
