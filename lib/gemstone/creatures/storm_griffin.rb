{
  schema_version: 3,
  name: "storm griffin",
  noun: "griffin",
  url: "https://gswiki.play.net/storm_griffin",
  picture: "",
  level: 73,
  family: "Griffin",
  type: "Hybrid",
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
    "Living",
    "Magical"
  ],
  bcs: true,
  max_hp: 400,
  speed: 8,
  height: 5,
  size: "large",
  areas: [
    {
      name: "Griffin's Keen",
      uids: [13302101..13302142]
    },
    {
      name: "Stormpeak",
      uids: [13150301..13150322]
    },
    {
      name: "unmapped",
      uids: [13150323..13150324]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (338..368)
      },
      {
        name: "Impale",
        as: 358
      },
      {
        name: "Bite",
        as: (327..362)
      },
      {
        name: "Swoop",
        as: (331..368)
      },
      {
        name: "Beak",
        as: 325
      },
      {
        name: "Powerful lightning bolt",
        as: 293
      }
    ],
    bolt_spells: [
      {
        name: "Major Shock (910)",
        as: 321
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Call Wind (912)"
      },
      {
        name: "Lightning mote"
      },
      {
        name: "Screech"
      }
    ],
    maneuvers: [
      {
        name: "Wing Buffet"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (155..347),
    ranged: (173..306),
    bolt: (173..306),
    udf: (262..509),
    bar_td: nil,
    cle_td: (287..293),
    emp_td: (288..294),
    pal_td: (242..251),
    ran_td: (251..257),
    sor_td: (297..315),
    wiz_td: nil,
    mje_td: 314,
    mne_td: 314,
    mjs_td: 279,
    mns_td: 279,
    mnm_td: (234..243),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: false,
    skin: "soft blue griffin feather",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The storm griffin is a magnificent beast, as if designed by the gods to embody fierce and graceful predation. Its front legs, forebody, wings, and head are those of a great eagle, complete with large powder-blue feathers and aquiline beak. The rear half of the creature's body is that of a powerful lion, with short, sandy blonde fur and a long feline tail. A tendril of electricity snakes across one outstreched claw as the storm griffin glares about with its piercing blue eyes."
    ],
    arrival: [
      "A storm griffin just arrived."
    ],
    flee: [
      "A storm griffin flies {direction}."
    ],
    death: [
      "The storm griffin writhes in agony, its wings flapping fruitlessly as it dies.",
      "The storm griffin crashes to the ground, motionless."
    ],
    decay: [
      "The storm griffin decays into a pile of feathers and fur."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A storm griffin rakes at you with a razor-sharp claw!",
        "A storm griffin tries to spear you with {pronoun} beak!"
      ],
      bite: [
        "A storm griffin tries to bite you!"
      ],
      claw: [
        "A storm griffin rakes at {target} with a razor-sharp claw!"
      ],
      hurl: [
        "A storm griffin hurls {weapon} at you!"
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
