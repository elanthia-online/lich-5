{
  schema_version: 3,
  name: "vourkha",
  noun: "vourkha",
  url: "https://gswiki.play.net/vourkha",
  picture: "",
  level: 39,
  family: "Wraith",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 238,
  speed: 5,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Yegharren Plains",
      uids: [13036106..13036120, 13036201..13036217, 13036301..13036310]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (226..252)
      },
      {
        name: "Claw",
        as: (235..262)
      },
      {
        name: "Swoop",
        as: 235
      }
    ],
    bolt_spells: [
      {
        name: "Minor Acid (904)",
        as: 217
      },
      {
        name: "Minor Fire (906)",
        as: 217
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "7N",
    immunities: [],
    melee: (136..283),
    ranged: (134..180),
    bolt: (134..180),
    udf: (163..322),
    bar_td: 135,
    cle_td: (148..157),
    emp_td: (148..154),
    pal_td: (126..135),
    ran_td: (122..135),
    sor_td: (149..164),
    wiz_td: nil,
    mje_td: (162..163),
    mne_td: (162..163),
    mjs_td: (148..157),
    mns_td: (148..157),
    mnm_td: (127..136),
    defensive_spells: [
      "Elemental Bias (508)",
      "Thurfel's Ward (503)"
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
    "a completely severed left arm",
    "a completely severed left hand"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Glowing violet essence dust",
      "glowing violet essence shard"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Empty black soulless eyes gaze from the gaunt, grey form of the wraithlike vourkha. His thin-lipped mouth gaped in a silent howl, he grasps at the fetid air with gnarled, clawed hands as he glides just above the ground, trailing tendrils of thick white ectoplasm that seem to seep from his shredded clothing. The creature seems to fade in and out of corporeal existence as if he walked in an eternal patch of shadow."
    ],
    arrival: [
      "An evil hiss fills the air as a vourkha stalks in!"
    ],
    flee: [
      "An evil hiss fills the air as a vourkha stalks {direction}.",
      "A vourkha totters momentarily and then heads {direction}."
    ],
    death: [
      "The vourkha slumps to the ground as the light departs {pronoun} eyes."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A vourkha tosses {pronoun} head back and points towards you!"
      ],
      bite: [
        "A vourkha tries to bite you!"
      ],
      claw: [
        "A vourkha claws at you!"
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
