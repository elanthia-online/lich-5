{
  schema_version: 3,
  name: "lesser griffin",
  noun: "griffin",
  url: "https://gswiki.play.net/lesser_griffin",
  picture: "",
  level: 69,
  family: "Griffin",
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
  boss_type: "pack",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 400,
  speed: 8,
  height: 5,
  size: "large",
  areas: [
    {
      name: "Griffin's Keen",
      uids: [13302101..13302169]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Impale",
        as: 341
      },
      {
        name: "Bite",
        as: (338..341)
      },
      {
        name: "Claw",
        as: (348..351)
      },
      {
        name: "Beak",
        as: 329
      },
      {
        name: "Swoop",
        as: (315..344)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Screech"
      },
      {
        name: "Wing Swat"
      },
      {
        name: "Dive"
      },
      {
        name: "Wing Buffet"
      }
    ],
    special_abilities: [
      {
        name: "Buffet"
      },
      {
        name: "Screech"
      },
      {
        name: "Wing Swat"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (206..324),
    ranged: (180..293),
    bolt: (180..293),
    udf: 392,
    bar_td: 246,
    cle_td: (269..278),
    emp_td: (267..273),
    pal_td: (226..235),
    ran_td: 226,
    sor_td: (278..290),
    wiz_td: nil,
    mje_td: (285..304),
    mne_td: (285..304),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: (213..222),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a blinded left eye",
    "a completely severed left front leg"
  ],
  treasure: {
    coins: true,
    magic_items: false,
    gems: true,
    boxes: false,
    skin: "ruffed tawny griffin pelt",
    other: [
      "Glowing violet essence dust",
      "glowing violet essence shard"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The lesser griffin is a magnificent beast, as if designed by the gods to embody fierce and graceful predation. Its front legs, forebody, wings, and head are those of a great eagle, complete with large white feathers and aquiline beak. The rear half of the creature's body is that of a powerful lion, with short tawny fur and a long feline tail. Emphasized by its size, which is larger than a warhorse, the griffin's renowned majestic presence and great bravery have earned the creature a place on many nobles' coats-of-arms."
    ],
    arrival: [
      "A lesser griffin just arrived."
    ],
    flee: [
      "A lesser griffin flies {direction}."
    ],
    death: [
      "The lesser griffin writhes in agony, its wings flapping fruitlessly as it dies.",
      "The lesser griffin crashes to the ground, motionless."
    ],
    decay: [
      "The lesser griffin decays into a pile of feathers and fur."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A lesser griffin regains {pronoun} composure and begins moving again."
    ],
    attacks: {
      attack: [
        "A lesser griffin rakes at you with a razor-sharp claw!",
        "A lesser griffin tries to spear you with {pronoun} beak!"
      ],
      bite: [
        "A lesser griffin tries to bite you!"
      ],
      claw: [
        "A lesser griffin rakes at {target} with a razor-sharp claw!"
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
