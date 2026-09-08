{
  schema_version: 3,
  name: "lesser shade",
  noun: "shade",
  url: "https://gswiki.play.net/lesser_shade",
  picture: "",
  level: 2,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 44,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Coastal Cliffs",
      uids: [2163601..2163628]
    },
    {
      name: "Catacombs",
      uids: [46007..46010, 46017..46018]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Short sword",
        as: (33..43)
      },
      {
        name: "Falchion",
        as: 43
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Calm (201)",
        cs: 10
      },
      {
        name: "Repel (fear)",
        cs: 14
      },
      {
        name: "Mottled grey falchion",
        cs: 10
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "18",
    immunities: [],
    melee: -17,
    ranged: -20,
    bolt: -20,
    udf: 17,
    bar_td: 6,
    cle_td: 6,
    emp_td: 6,
    pal_td: (3..6),
    ran_td: 6,
    sor_td: 6,
    wiz_td: nil,
    mje_td: 6,
    mne_td: 6,
    mjs_td: 6,
    mns_td: 6,
    mnm_td: 6,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a short sword",
    "an augmented breastplate"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Alchemy (common)",
    armaments: [
      "mottled grey falchion"
    ],
    transmogs: nil
  },
  messaging: {
    description: [
      "The lesser shade bears the outline of a man and looks solid, but you can see faint images of the background through it."
    ],
    arrival: [
      "A lesser shade just arrived."
    ],
    flee: [],
    death: [
      "The lesser shade falls to the ground motionless."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A lesser shade swings {weapon} at you!"
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
