{
  schema_version: 3,
  name: "bresnahanini rolton",
  noun: "rolton",
  url: "https://gswiki.play.net/bresnahanini_rolton",
  picture: "",
  level: 3,
  family: "Caprine",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 44,
  speed: 13,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Outlands",
      uids: [4215701..4215716]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite (attack)",
        as: 60
      },
      {
        name: "Charge (attack)",
        as: 70
      },
      {
        name: "Bite",
        as: (48..50)
      },
      {
        name: "Charge",
        as: 63
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
    asg: "5N",
    immunities: [],
    melee: (18..45),
    ranged: 17,
    bolt: 17,
    udf: (63..74),
    bar_td: nil,
    cle_td: 9,
    emp_td: 9,
    pal_td: (6..9),
    ran_td: 9,
    sor_td: 9,
    wiz_td: nil,
    mje_td: 9,
    mne_td: 9,
    mjs_td: 9,
    mns_td: 9,
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
    skin: "a rolton horn",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Nearly four feet at the shoulder, and graced with a pair of large, curled horns, the Bresnahanini rolton is a larger and meaner version of his standard cousin. Sometimes called the curly-horned rolton, this species is reputed to have even killed a lord or two."
    ],
    arrival: [],
    flee: [
      "A Bresnahanini rolton trots {direction}.",
      "A bresnahanini rolton trots {direction}, snorting and scanning the area.",
      "A bresnahanini rolton bleats as {pronoun} slowly backs away."
    ],
    death: [
      "The Bresnahanini rolton collapses to the ground, emits a final bleat, and dies.",
      "The Bresnahanini rolton lets out a final agonized bleat and dies."
    ],
    decay: [
      "A Bresnahanini rolton decays into a pile of fur and bone."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A Bresnahanini rolton charges at you!"
      ],
      bite: [
        "A Bresnahanini rolton tries to bite you!"
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
