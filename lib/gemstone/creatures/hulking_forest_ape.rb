{
  schema_version: 3,
  name: "hulking forest ape",
  noun: "ape",
  url: "https://gswiki.play.net/hulking_forest_ape",
  picture: "",
  level: 31,
  family: "Primate",
  type: "Quadruped",
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
  max_hp: 360,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Cloud Forest",
      uids: [3219001..3219038]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound (attack)",
        as: (200..278)
      },
      {
        name: "Bite (attack)",
        as: (200..278)
      },
      {
        name: "Charge (attack)",
        as: (200..278)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Pounce"
      }
    ],
    special_abilities: [
      {
        name: "Pounce"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "16N",
    immunities: [],
    melee: (111..260),
    ranged: (124..154),
    bolt: (124..154),
    udf: (210..290),
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: (90..99),
    sor_td: 117,
    wiz_td: nil,
    mje_td: 135,
    mne_td: 135,
    mjs_td: nil,
    mns_td: 96,
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
    coins: true,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a dark brown forest ape pelt",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      ""
    ],
    arrival: [
      "A hulking forest ape lopes in on {pronoun} hind legs and knuckles."
    ],
    flee: [
      "A hulking forest ape backs away on all fours, puffing out {pronoun} chest in an attempt to look bigger."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A hulking forest ape lunges forward at you on {pronoun} powerful limbs!",
        "A hulking forest ape snaps at you with sharp teeth and strong jaws!",
        "A hulking forest ape pounces at you and connects!"
      ],
      bite: [
        "A hulking forest ape snaps at you with sharp teeth and strong jaws!"
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
