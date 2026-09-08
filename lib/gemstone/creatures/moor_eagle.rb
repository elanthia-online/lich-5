{
  schema_version: 3,
  name: "moor eagle",
  noun: "eagle",
  url: "https://gswiki.play.net/moor_eagle",
  picture: "",
  level: 35,
  family: "Bird",
  type: "Avian",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 400,
  speed: 9,
  height: 2,
  size: "large",
  areas: [
    {
      name: "Shattered Moors",
      uids: [420001..420025]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (233..259)
      },
      {
        name: "Impale",
        as: 249
      },
      {
        name: "Swoop",
        as: 267
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Dive"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (171..213),
    ranged: (143..203),
    bolt: (143..203),
    udf: (196..238),
    bar_td: 109,
    cle_td: (118..127),
    emp_td: (117..130),
    pal_td: (105..114),
    ran_td: (105..111),
    sor_td: (125..134),
    wiz_td: nil,
    mje_td: 134,
    mne_td: 134,
    mjs_td: (113..121),
    mns_td: (113..121),
    mnm_td: (105..111),
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
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "moor eagle talon",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Wide, snow white wings spread ten feet across as the moor eagle soars in flight. Pale yellow feet extend below the bird's light grey, feathered body, the feet displaying razor-sharp talons that look long and strong enough to powerfully grasp most anything the eagle might encounter. A large, hooked beak protrudes from the moor eagle's head. In contrast to the muted colors on the rest of the moor eagle, the eagle's eyes are a striking sky blue."
    ],
    arrival: [],
    flee: [
      "A moor eagle flies {direction}."
    ],
    death: [
      "The moor eagle flops about on the ground, {pronoun} thrashing finally ceasing in death.",
      "The moor eagle augers into the ground, {pronoun} death spiral ending in a **THUD**."
    ],
    decay: [
      "The moor eagle decays into a pile of feathers."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A moor eagle rakes at you with a razor-sharp claw!",
        "A moor eagle tries to impale you on {pronoun} beak!"
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
