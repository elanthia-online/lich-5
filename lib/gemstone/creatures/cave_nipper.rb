{
  schema_version: 3,
  name: "cave nipper",
  noun: "nipper",
  url: "https://gswiki.play.net/cave_nipper",
  picture: "",
  level: 3,
  family: "Reptilian",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
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
  max_hp: 42,
  speed: 8,
  height: 1,
  size: "medium",
  areas: [
    {
      name: "Sea Caverns",
      uids: [391001..391022]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge",
        as: (43..63)
      },
      {
        name: "Unknown",
        as: 53
      },
      {
        name: "Claw",
        as: 53
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
    asg: nil,
    immunities: [],
    melee: (26..33),
    ranged: (20..30),
    bolt: (20..30),
    udf: 45,
    bar_td: nil,
    cle_td: 9,
    emp_td: 9,
    pal_td: (6..9),
    ran_td: 9,
    sor_td: 9,
    wiz_td: nil,
    mje_td: 9,
    mne_td: 9,
    mjs_td: (6..9),
    mns_td: (6..9),
    mnm_td: 9,
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
    gems: nil,
    boxes: nil,
    skin: "a cave nipper's ",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "More serpent than lizard, the cave nipper is nearly as long as a human is tall, though less thick. It has a short and stubby tail, virtually no neck, and legs so stumpy that they are nearly nonexistent. A brown back shading off to a tannish underside allows this beast to blend in among the rocks and moss of its habitat. Moving swiftly and showing great strength for its size, the cave nipper will pursue and capture prey much larger than itself. This one is sizing up its next meal through cold, unblinking, reptilian eyes that stare out from its thick, blunt-nosed head. Its tongue flicks out quickly, as if gathering your scent."
    ],
    arrival: [
      "A cave nipper slithers in!"
    ],
    flee: [
      "A cave nipper slithers {direction}."
    ],
    death: [
      "The cave nipper hisses one last time and dies."
    ],
    decay: [
      "A cave nipper decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A cave nipper charges at you!"
      ],
      claw: [
        "A cave nipper claws at you!"
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
