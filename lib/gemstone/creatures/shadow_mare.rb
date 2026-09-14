{
  schema_version: 3,
  name: "shadow mare",
  noun: "mare",
  url: "https://gswiki.play.net/shadow_mare",
  picture: "",
  level: 37,
  family: "Equine",
  type: "Quadruped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: true,
  max_hp: 260,
  speed: nil,
  height: 6,
  size: "large",
  areas: [
    {
      name: "Shadow Valley",
      uids: [389030..389035, 2160001..2160035, 2161001..2161022]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (188..211)
      },
      {
        name: "Foot",
        as: (188..211)
      },
      {
        name: "Charge",
        as: 175
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Ethereal Wave"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (144..333),
    ranged: (110..201),
    bolt: (110..201),
    udf: (188..343),
    bar_td: nil,
    cle_td: (129..138),
    emp_td: (130..139),
    pal_td: (111..120),
    ran_td: (111..117),
    sor_td: (136..145),
    wiz_td: nil,
    mje_td: (137..143),
    mne_td: (137..143),
    mjs_td: 285,
    mns_td: 285,
    mnm_td: (123..132),
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
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "a silver-tipped horseshoe",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The features of this horror are difficult to make out due to the shifting of its shadowy hide which instantly assumes the color of its surroundings. Despite the strange effect, its eyes glow red and a wave of ethereal light flashes across its mane."
    ],
    arrival: [],
    flee: [
      "A shadow mare trots {direction}.",
      "A shadow mare gallops {direction}.",
      "A shadow mare runs {direction}."
    ],
    death: [
      "The shadow mare falls to the ground motionless.",
      "The shadow mare ceases all attempts at movement."
    ],
    decay: [
      "A shadow mare's eyes go dim as she dissolves into the shadows."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A shadow mare stomps at you with {pronoun} foot!",
        "A shadow mare charges at you!",
        "A shadow mare directs {pronoun} gaze at you!"
      ],
      bite: [
        "A shadow mare tries to bite you!"
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
