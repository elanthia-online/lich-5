{
  schema_version: 3,
  name: "carceris",
  noun: "carceris",
  url: "https://gswiki.play.net/carceris",
  picture: "",
  level: 25,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: nil,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 204,
  speed: 6,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "Castle Anwyn",
      uids: [4285030..4285050]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Major Cold (907)",
        as: 160
      },
      {
        name: "Major Fire (908)",
        as: 160
      },
      {
        name: "Major Shock (910)",
        as: 160
      },
      {
        name: "Bite",
        as: 189
      },
      {
        name: "Claw",
        as: 139
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Earthen Fury (917)"
      }
    ],
    maneuvers: [
      {
        name: "Gesture"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6",
    immunities: [],
    melee: (150..311),
    ranged: (153..193),
    bolt: (140..210),
    udf: (267..301),
    bar_td: 86,
    cle_td: (80..87),
    emp_td: (82..89),
    pal_td: (70..80),
    ran_td: (73..80),
    sor_td: (87..97),
    wiz_td: nil,
    mje_td: (96..101),
    mne_td: (96..101),
    mjs_td: (82..89),
    mns_td: (82..89),
    mnm_td: (75..82),
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Prismatic Guard (905)",
      "Mass Blur (911)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "some old tattered armor",
    "a mangled shield"
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
      "The carceris makes a peculiar rustling sound as she moves, reminiscent of dried up parchment. The carceris's ragged robes lift and swirl about her like animated tendrils, and bare bones protrude from similar tatters of skin hanging from her hands and hollow cheeks. The specter bares yellowed teeth, the roots discolored a deep brown where they are anchored in the visible jawbones. As she circles, constantly whispering a litany of magic, gooey pools of darkness which were once the horror's eyes weep rivulets of stain down the remnants of her face."
    ],
    arrival: [
      "A carceris shambles in!",
      "A carceris just came through an arched door leading into the old Castle Keep."
    ],
    flee: [
      "A carceris shambles {direction}.",
      "A carceris wails madly as she limps {direction}.",
      "A carceris just went through an arched door leading into the old Castle Keep."
    ],
    death: [
      "The carceris falls to the ground motionless.",
      "The carceris wails in terrifying pain one last time and lies still."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A carceris chants an utterly incomprehensible phrase."
    ],
    attacks: {
      attack: [
        "A carceris gestures at you!"
      ],
      bite: [
        "A carceris tries to bite you!"
      ],
      claw: [
        "A carceris claws at you!"
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
