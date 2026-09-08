{
  schema_version: 3,
  name: "nightmare steed",
  noun: "steed",
  url: "https://gswiki.play.net/nightmare_steed",
  picture: "",
  level: 55,
  family: "Equine",
  type: "Quadruped",
  undead: true,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: nil,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: nil,
  speed: 5,
  height: nil,
  size: "",
  areas: [
    {
      name: "Darkstone Castle",
      uids: []
    },
    {
      name: "The Broken Lands",
      uids: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 327
      },
      {
        name: "Charge",
        as: 337
      },
      {
        name: "Foot",
        as: 327
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
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
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
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a silver mane",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The mighty nightmare steed stands defiantly at all around it staring blankly with cold rage, filled with malice and a clear desire to rend flesh from limb to limb. It has midnight black hair and a silky silver mane with occasional black streaks. The eyes of a nightmare steed shine with a brilliant red glow that never are seen to blink very often, if at all."
    ],
    arrival: [],
    flee: [
      "The steed gallops {direction}.",
      "A nightmare steed gallops {direction}."
    ],
    death: [
      "The nightmare steed screams one last time and dies."
    ],
    decay: [],
    search: [
      "A nightmare steed glances around, sure {pronoun} has missed something."
    ],
    spell_prep: [],
    attacks: {
      attack: [
        "A nightmare steed charges at you!",
        "A nightmare steed stomps at you with {pronoun} foot!"
      ],
      bite: [
        "A nightmare steed tries to bite you!"
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
