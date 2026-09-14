{
  schema_version: 3,
  name: "ghostly pooka",
  noun: "pooka",
  url: "https://gswiki.play.net/ghostly_pooka",
  picture: "",
  level: 33,
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
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Non-corporeal undead",
    "Boss"
  ],
  bcs: true,
  max_hp: 262,
  speed: 11,
  height: 5,
  size: "large",
  areas: [
    {
      name: "Shadow Valley",
      uids: [389001..389019, 389021..389027, 2158001..2158020]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (189..217)
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
    melee: (113..268),
    ranged: (107..142),
    bolt: (107..142),
    udf: (189..329),
    bar_td: nil,
    cle_td: (100..109),
    emp_td: (110..117),
    pal_td: (96..106),
    ran_td: (96..106),
    sor_td: (119..128),
    wiz_td: nil,
    mje_td: 134,
    mne_td: 134,
    mjs_td: 148,
    mns_td: 148,
    mnm_td: (99..105),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "some heavy chains",
    "some torn"
  ],
  treasure: {
    coins: true,
    magic_items: false,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Alchemy (common)",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The most stunning thing about the appearance of a ghostly pooka is the odd illusion surrounding this pitiful equine which seems to absorb all the color from everything around it. The ghostly horse appears to be weighed down by some heavy chains which cover its entire body. The sight of its obvious torment tears at the souls of all who lay eyes upon it."
    ],
    arrival: [],
    flee: [
      "A shimmering ghostly pooka gallops {direction}.",
      "A ghostly pooka trots {direction}.",
      "A ghostly pooka runs {direction}.",
      "A ghostly pooka gallops {direction}."
    ],
    death: [
      "The ghostly pooka falls to the ground motionless.",
      "The ghostly pooka ceases all attempts at movement."
    ],
    decay: [
      "A ghostly pooka fades away as if {pronoun} were never there."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      bite: [
        "A ghostly pooka tries to bite you!",
        "A pooka tries to bite you!"
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
