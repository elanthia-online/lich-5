{
  schema_version: 3,
  name: "moor witch",
  noun: "witch",
  url: "https://gswiki.play.net/moor_witch",
  picture: "",
  level: 34,
  family: "Witch",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Shattered Moors",
      uids: [420001..420037, 420040..420046]
    },
    {
      name: "unmapped",
      uids: [420038..420039]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Dagger",
        as: (211..252)
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
    asg: "2",
    immunities: [],
    melee: (228..301),
    ranged: (164..242),
    bolt: (164..242),
    udf: (224..320),
    bar_td: 135,
    cle_td: (121..130),
    emp_td: (125..135),
    pal_td: (106..115),
    ran_td: (106..115),
    sor_td: (134..147),
    wiz_td: nil,
    mje_td: (126..135),
    mne_td: (126..135),
    mjs_td: (116..125),
    mns_td: (116..125),
    mnm_td: (129..139),
    defensive_spells: [
      "Elemental Defense I",
      "Elemental Defense II",
      "Elemental Defense III",
      "Elemental Targeting",
      "Lesser Shroud",
      "Spirit Defense",
      "Spirit Warding II"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a diaphanous robe",
    "a twisted dagger"
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
    description: [],
    arrival: [
      "A moor witch appears in a graceful glide, small feet carrying {pronoun} almost silently!"
    ],
    flee: [
      "A moor witch hobbles {direction}.",
      "A wavering moor witch hobbles {direction}."
    ],
    death: [
      "The moor witch's face takes on a surprised expression and she collapses, motionless."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      bite: [
        "A moor witch snaps {pronoun} head to the side in a vain attempt to clear {pronoun} thoughts."
      ],
      attack: [
        "A moor witch swings {weapon} at you!",
        "A moor witch screams an angry torrent of curses and points at you!"
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
