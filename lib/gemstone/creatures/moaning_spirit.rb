{
  schema_version: 3,
  name: "moaning spirit",
  noun: "spirit",
  url: "https://gswiki.play.net/moaning_spirit",
  picture: "",
  level: 28,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 225,
  speed: 12,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Castle Anwyn",
      uids: [4285004..4285008, 4285013..4285013, 4285024..4285025]
    },
    {
      name: "The Graveyard",
      uids: [2150002..2150007]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (218..235)
      },
      {
        name: "Closed fist",
        as: (228..245)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Claw",
        cs: 159
      },
      {
        name: "Closed fist",
        cs: 154
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Mystic Gesture"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (150..188),
    ranged: (94..188),
    bolt: (94..188),
    udf: (153..165),
    bar_td: nil,
    cle_td: 91,
    emp_td: 93,
    pal_td: nil,
    ran_td: 84,
    sor_td: 97,
    wiz_td: nil,
    mje_td: 100,
    mne_td: 100,
    mjs_td: (93..101),
    mns_td: (93..101),
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "glimmering blue essence dust",
      "ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Intense hatred for those living drives the moaning spirit to traverse the bounds of space to attack its enemies. Crying out in constant pain, it marshals magic, claw and fist against its foes, destroying relentlessly to sate the desires of the forces that bind it, then returning whence it came to await the intrusion of another living creature. Its semi-transparent countenance is passably humanoid, save for the eagle-like claws replacing what would normally be the human's feet."
    ],
    arrival: [
      "A moaning spirit just arrived."
    ],
    flee: [
      "A moaning spirit withdraws, disengaging from {target}."
    ],
    death: [
      "The moaning spirit falls to the ground motionless.",
      "A moaning spirit collapses into a puddle of jelly, falling silent at last."
    ],
    decay: [
      "A moaning spirit collapses into a puddle of jelly, falling silent at last.",
      "A small, green cloud of smelly gas rises from the body of a big ugly kobold as {pronoun} decays into compost."
    ],
    search: [],
    spell_prep: [
      "A moaning spirit begins to chant an eerie tune!"
    ],
    attacks: {
      attack: [
        "A moaning spirit gestures at you!",
        "A moaning spirit swings {weapon} at you!",
        "A moaning spirit swings a closed fist at {target}!"
      ],
      claw: [
        "A moaning spirit claws at {target}!"
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
