{
  schema_version: 3,
  name: "war griffin",
  noun: "griffin",
  url: "https://gswiki.play.net/war_griffin",
  picture: "",
  level: 100,
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
    "Living"
  ],
  bcs: true,
  max_hp: 400,
  speed: 7,
  height: 6,
  size: "large",
  areas: [
    {
      name: "Old Ta'Faendryl",
      uids: [17004001..17004028, 17004030..17004120, 17004160..17004168, 17004180..17004187, 17004190..17004195]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (465..475)
      },
      {
        name: "Claw",
        as: (465..467)
      },
      {
        name: "Impale",
        as: 436
      },
      {
        name: "Beak",
        as: (444..471)
      },
      {
        name: "Smash",
        as: 443
      },
      {
        name: "Swoop",
        as: (457..475)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Call Wind (912)"
      },
      {
        name: "Screech"
      },
      {
        name: "Wing buffet"
      },
      {
        name: "Wing swat"
      },
      {
        name: "Dive"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: (168..348),
    ranged: (184..358),
    bolt: (184..358),
    udf: (415..542),
    bar_td: 390,
    cle_td: (424..433),
    emp_td: (415..424),
    pal_td: (366..375),
    ran_td: 360,
    sor_td: (439..448),
    wiz_td: nil,
    mje_td: (457..561),
    mne_td: (457..561),
    mjs_td: (381..388),
    mns_td: (381..388),
    mnm_td: (351..360),
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
    boxes: nil,
    skin: "a war griffin talon",
    other: "Alchemy",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The war griffin is a magnificent beast, as if designed by the gods to embody fierce and graceful predation. Its front legs, forebody, wings, and head are those of a great eagle, complete with large golden feathers and aquiline beak. The rear half of the creature's body is that of a powerful lion, with short white fur and a long feline tail. Trained by its captors to enhance its fighting prowess, the massive war griffin is poetry in motion, its beautiful ferocity the last sight its foes ever see."
    ],
    arrival: [],
    flee: [
      "A war griffin flies {direction}."
    ],
    death: [
      "The war griffin writhes in agony, its wings flapping fruitlessly as it dies.",
      "The war griffin crashes to the ground, motionless."
    ],
    decay: [
      "The war griffin decays into a pile of feathers and fur."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A war griffin rakes at you with a razor-sharp claw!",
        "A war griffin tries to spear you with {pronoun} beak!"
      ],
      bite: [
        "A war griffin tries to bite you!"
      ],
      claw: [
        "A war griffin rakes at {target} with a razor-sharp claw!"
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
