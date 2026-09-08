{
  schema_version: 3,
  name: "fenghai",
  noun: "fenghai",
  url: "https://gswiki.play.net/fenghai",
  picture: "",
  level: 23,
  family: "Fey",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
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
  max_hp: 190,
  speed: 6,
  height: 2,
  size: "medium",
  areas: [
    {
      name: "Vornavian Coast",
      uids: [4006001..4006031, 4218101..4218121]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "kris",
        as: (146..173)
      },
      {
        name: "Freezing ball of pure cold",
        as: 200
      },
      {
        name: "Hissing stream of acid",
        as: 206
      },
      {
        name: "Large boulder",
        as: 123
      },
      {
        name: "Powerful lightning bolt",
        as: 208
      },
      {
        name: "Scimitar",
        as: 209
      },
      {
        name: "Small surge of electricity",
        as: 202
      },
      {
        name: "Stream of fire",
        as: 167
      },
      {
        name: "Fist",
        as: 133
      }
    ],
    bolt_spells: [
      {
        name: "Minor Acid (904)",
        as: 167
      },
      {
        name: "Major Cold (907)",
        as: (160..167)
      },
      {
        name: "Major Fire (908)",
        as: 178
      },
      {
        name: "Minor Shock (901)",
        as: 167
      }
    ],
    warding_spells: [
      {
        name: "Point",
        cs: 145
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (158..333),
    ranged: (116..200),
    bolt: (116..200),
    udf: (146..285),
    bar_td: 76,
    cle_td: (146..161),
    emp_td: (161..171),
    pal_td: (135..146),
    ran_td: (143..149),
    sor_td: (94..165),
    wiz_td: nil,
    mje_td: (83..97),
    mne_td: (83..97),
    mjs_td: (151..160),
    mns_td: (151..160),
    mnm_td: (155..165),
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Elemental Focus (513)",
      "Thurfel's Ward (503)",
      "Wizard's Shield (919)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye",
    "a bruised right eye",
    "a greatsword",
    "a scimitar"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a fenghai fur",
    other: [
      "Glimmering blue essence shard",
      "s'ayanad crystal",
      "ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The fenghai seems to be a furry little ball with feet. Sparkling eyes peer out from a mop of russet fur, looking about with a happy curiousity. Stubby arms end in pudgy little hands that appear dextrous despite their dimensions, and the round-toed feet are covered in hair and dirt. While comical in appearance, it is obvious that the furball can take care of itself."
    ],
    arrival: [],
    flee: [
      "A fenghai scurries {direction}.",
      "A glowing fenghai scurries {direction}.",
      "A flashy fenghai scurries {direction}."
    ],
    death: [
      "The fenghai falls to the ground motionless.",
      "The fenghai cries out one last time and lies still.",
      "A fenghai crumples in on {reflexive}, a tangled mess of fur and flesh."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A fenghai glows brightly!",
      "A fenghai murmurs quietly to {reflexive}."
    ],
    attacks: {
      attack: [
        "A fenghai swings {weapon} at you!",
        "A fenghai pounds at you with {pronoun} fist!",
        "A fenghai swings a scimitar at {target}!",
        "A fenghai swings a greatsword at {target}!"
      ],
      bolt: [
        "A fenghai hurls a stream of fire at {target}!"
      ],
      cast: [
        "A fenghai points a furry finger at {target}!"
      ],
      hurl: [
        "A fenghai hurls {weapon} at you!",
        "A fenghai hurls a large boulder at {target}!"
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
