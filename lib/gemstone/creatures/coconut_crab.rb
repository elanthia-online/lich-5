{
  schema_version: 3,
  name: "coconut crab",
  noun: "crab",
  url: "https://gswiki.play.net/coconut_crab",
  picture: "",
  level: 2,
  family: "Crab",
  type: "Crustacean",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 32,
  speed: nil,
  height: 1,
  size: "small",
  areas: [
    {
      name: "Rocky Shoals",
      uids: [7127001..7127019]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 43
      },
      {
        name: "Unknown",
        as: 53
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
    melee: 37,
    ranged: 34,
    bolt: 34,
    udf: 44,
    bar_td: nil,
    cle_td: 6,
    emp_td: (3..6),
    pal_td: (3..6),
    ran_td: 6,
    sor_td: 6,
    wiz_td: nil,
    mje_td: 6,
    mne_td: 6,
    mjs_td: (3..6),
    mns_td: (3..6),
    mnm_td: 6,
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
    magic_items: true,
    gems: true,
    boxes: nil,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      ""
    ],
    arrival: [],
    flee: [
      "The crab skitters {direction}."
    ],
    death: [
      "The coconut crab falls back into a heap and dies.",
      "The coconut crab hisses one last time and dies."
    ],
    decay: [
      "A coconut crab decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A coconut crab tries to ensnare {target}!"
      ],
      claw: [
        "A coconut crab claws at {target}!"
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
