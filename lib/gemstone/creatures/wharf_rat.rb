{
  schema_version: 3,
  name: "wharf rat",
  noun: "rat",
  url: "https://gswiki.play.net/wharf_rat",
  picture: "",
  level: nil,
  family: "Rodent",
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
  otherclass: [],
  bcs: true,
  max_hp: 24,
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
        name: "Bite",
        as: 4
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
    melee: 14,
    ranged: 12,
    bolt: 12,
    udf: 24,
    bar_td: nil,
    cle_td: 3,
    emp_td: 3,
    pal_td: 3,
    ran_td: 3,
    sor_td: 3,
    wiz_td: nil,
    mje_td: 3,
    mne_td: 3,
    mjs_td: (3..6),
    mns_td: (3..6),
    mnm_td: 3,
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
    skin: "fang",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      ""
    ],
    arrival: [
      "A choking fetid odor heralds the arrival of a wharf rat!",
      "A wharf rat scampers in!"
    ],
    flee: [
      "A wharf rat scampers {direction}."
    ],
    death: [
      "The wharf rat collapses to the ground, emits a final squeal, and dies.",
      "The wharf rat twitches and dies.",
      "The wharf rat collapses to the ground, emits a final silent squeal, and dies."
    ],
    decay: [
      "A wharf rat decays into a pile of mangy hair and bone."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      bite: [
        "A wharf rat tries to bite you!"
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
