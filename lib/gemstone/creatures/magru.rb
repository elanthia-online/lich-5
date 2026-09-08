{
  schema_version: 3,
  name: "magru",
  noun: "magru",
  url: "https://gswiki.play.net/magru",
  picture: "",
  level: 37,
  family: "Globoid",
  type: "Globoid",
  undead: false,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: nil,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 299,
  speed: 7,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "The Broken Lands",
      uids: [94002..94019]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound",
        as: 210
      },
      {
        name: "Fist",
        as: 260
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Stream of Fluid"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [
      "Fire"
    ],
    melee: (107..119),
    ranged: (98..125),
    bolt: (98..125),
    udf: nil,
    bar_td: nil,
    cle_td: 129,
    emp_td: 130,
    pal_td: (108..111),
    ran_td: 111,
    sor_td: 136,
    wiz_td: nil,
    mje_td: 143,
    mne_td: 143,
    mjs_td: 130,
    mns_td: 130,
    mnm_td: 111,
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
    coins: nil,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The magru appears to be a huge, gelatinous red lump that pulses, swelling and shrinking slightly with a hypnotic rhythm. Its skin glistens with a dark, disgusting ooze."
    ],
    arrival: [
      "A magru just arrived.",
      "A magru slides in."
    ],
    flee: [
      "A magru heads {direction}."
    ],
    death: [],
    decay: [
      "The magru collapses into a heap of quivering jelly."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A magru pounds at you with {pronoun} fist!"
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
