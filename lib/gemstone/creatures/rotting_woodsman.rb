{
  schema_version: 3,
  name: "rotting woodsman",
  noun: "woodsman",
  url: "https://gswiki.play.net/rotting_woodsman",
  picture: "",
  level: 23,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Corporeal undead",
    "Boss"
  ],
  bcs: true,
  max_hp: 260,
  speed: 11,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Plains of Vornavis",
      uids: [4212201..4212222]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Battle axe",
        as: 202
      },
      {
        name: "Huge logging axe",
        as: 207
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
    melee: (115..174),
    ranged: (115..169),
    bolt: (115..169),
    udf: (167..265),
    bar_td: 69,
    cle_td: (64..70),
    emp_td: (68..76),
    pal_td: (63..72),
    ran_td: (66..69),
    sor_td: (74..80),
    wiz_td: nil,
    mje_td: (77..79),
    mne_td: (77..79),
    mjs_td: (72..78),
    mns_td: (72..78),
    mnm_td: (63..69),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a huge logging axe",
    "some tattered rags"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "glimmering blue essence dust",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The rotting woodsman staggers about through the forests she once knew in life, now unable to obtain rest. Putrid flesh drips from her exposed bones, and only ragged patches of hair remain on her thick skull. Despite the lack of solid muscle, the rotting woodsman swings her axe with enormous power, felling the living as she once felled the immense trees of the forest."
    ],
    arrival: [
      "A robust rotting woodsman shambles in!",
      "A rotting woodsman shambles in!"
    ],
    flee: [
      "A rotting woodsman crawls {direction}.",
      "A rotting woodsman wails madly as he limps {direction}.",
      "A rotting woodsman shambles {direction}."
    ],
    death: [
      "The rotting woodsman falls to the ground, a lifeless lump of flesh."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A rotting woodsman swings {weapon} at you!",
        "A rotting woodsman waves {pronoun} arms around flinging bits of flesh towards you.",
        "A rotting woodsman lashes about the area unsteadily grasping at the air."
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
