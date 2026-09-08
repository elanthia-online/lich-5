{
  schema_version: 3,
  name: "jungle feyling",
  noun: "feyling",
  url: "https://gswiki.play.net/jungle_feyling",
  picture: "",
  level: 24,
  family: "Fey",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 301,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Monsoon Jungle",
      uids: [3218001..3218055, 3218062..3218063]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Fist-scythe",
        as: 198
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Hamstring"
      },
      {
        name: "Fist-scythe"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "11",
    immunities: [],
    melee: (144..197),
    ranged: (144..159),
    bolt: (144..159),
    udf: (344..369),
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: (69..78),
    sor_td: 79,
    wiz_td: nil,
    mje_td: (81..82),
    mne_td: (81..82),
    mjs_td: nil,
    mns_td: 76,
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
    "a boiled leather vest",
    "a fist-scythe",
    "a small buckler",
    "an enormous ginko nut shell hat"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Petite in body, the jungle feyling has spindled limbs that are gaunt and wiry. Enormous brown eyes are set within a head that seems almost too large for the neck that supports it, while knotted tufts of coarse dark brown hair falls in erratic coils about her leathery face. Garbed simply in hides and skins, the jungle feyling wears strange armor-like components across her arms, back, chest, and legs, while her head is covered in what looks like the shell of an enormous tropical nut."
    ],
    arrival: [],
    flee: [
      "The jungle feyling jogs {direction}."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A jungle feyling suddenly jabs at you with a fist-scythe."
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
