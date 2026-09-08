{
  schema_version: 3,
  name: "crested basilisk",
  noun: "basilisk",
  url: "https://gswiki.play.net/crested_basilisk",
  picture: "",
  level: 22,
  family: "Basilisk",
  type: "Hybrid",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 200,
  speed: 8,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Outlands",
      uids: [2152013..2152030]
    },
    {
      name: "Rambling Meadows",
      uids: [14006041..14006046, 14006048..14006060]
    },
    {
      name: "Yegharren Plains",
      uids: [13034401..13034416]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (206..220)
      },
      {
        name: "Claw",
        as: 221
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Paralyzing Gaze"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (100..198),
    ranged: (111..145),
    bolt: (111..145),
    udf: (149..216),
    bar_td: (66..72),
    cle_td: (66..78),
    emp_td: (68..76),
    pal_td: (63..78),
    ran_td: (66..72),
    sor_td: (64..73),
    wiz_td: 72,
    mje_td: (72..78),
    mne_td: (72..78),
    mjs_td: (68..107),
    mns_td: (68..107),
    mnm_td: (66..72),
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
    skin: "a basilisk crest",
    other: "s'ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The crested basilisk is the size of a large dog, but its vicious-looking talons and sharp, hooked beak are fearsome weapons indeed. Looking like a cross between a huge fighting rooster and a serpentine lizard, the crested basilisk gazes around with its hypnotic, paralyzing eyes as its scaled reptilian tail whips back and forth. A bright red crest, more reminiscent of a lizard than of a chicken, adorns its feathered head and neck."
    ],
    arrival: [
      "A crested basilisk stomps in and glares about.",
      "A combative crested basilisk stomps in and glares about.",
      "A belligerent crested basilisk stomps in and glares about.",
      "A canny crested basilisk stomps in and glares about.",
      "A deft crested basilisk stomps in and glares about.",
      "An adroit crested basilisk stomps in and glares about.",
      "A crested basilisk trots in and glares about!"
    ],
    flee: [
      "A crested basilisk hisses and stomps {direction}.",
      "A combative crested basilisk hisses and stomps {direction}.",
      "A belligerent crested basilisk hisses and stomps {direction}.",
      "A keen crested basilisk hisses and stomps {direction}.",
      "The crested basilisk comes up to you and sniffs you several times. A stricken look crosses {pronoun} visage and {pronoun} slowly backs away."
    ],
    death: [
      "The crested basilisk rolls over on its back, emits a final hiss and dies.",
      "The crested basilisk emits a final hiss and dies.",
      "The crested basilisk emits a final silent hiss and dies.",
      "The crested basilisk rolls over on its back, emits a final silent hiss and dies."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A crested basilisk hisses as {pronoun} stares hatefully at you.",
      "A crested basilisk hisses mournfully!",
      "A crested basilisk hisses deep in {pronoun} throat as {pronoun} fights to clear {pronoun} senses."
    ],
    attacks: {
      claw: [
        "A crested basilisk claws at you!"
      ],
      bite: [
        "A crested basilisk tries to bite you!"
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
