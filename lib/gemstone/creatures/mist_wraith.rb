{
  schema_version: 3,
  name: "mist wraith",
  noun: "wraith",
  url: "https://gswiki.play.net/mist_wraith",
  picture: "",
  level: 5,
  family: "Wraith",
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
  max_hp: 80,
  speed: 7,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Glaise Cnoc Cemetery",
      uids: [14008051..14008070]
    },
    {
      name: "The Citadel",
      uids: [2102022..2102039]
    },
    {
      name: "Cairnfang",
      uids: [630001..630014]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 81
      },
      {
        name: "Claw",
        as: 71
      },
      {
        name: "Ensnare",
        as: (71..81)
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
    asg: "8N",
    immunities: [],
    melee: (-10..72),
    ranged: 4,
    bolt: (-11..4),
    udf: (1..77),
    bar_td: 15,
    cle_td: 15,
    emp_td: 15,
    pal_td: (12..15),
    ran_td: 15,
    sor_td: 15,
    wiz_td: 15,
    mje_td: 15,
    mne_td: 15,
    mjs_td: (12..15),
    mns_td: (12..15),
    mnm_td: 15,
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
    boxes: true,
    skin: "mist wraith eye",
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The smaller cousin to the normal lifeleeching wraith, the mist wraith is the spirit of a soldier vanquished in a great battle. The spirits trap the mist of the local area and use it to give them a semi-physical form with which to exact vengeance. This results in their powerful claws and arms with which to rip the living apart."
    ],
    arrival: [
      "A mist wraith just arrived!",
      "A mist wraith just arrived."
    ],
    flee: [],
    death: [
      "The mist wraith falls to the ground motionless.",
      "The mist wraith screams evilly one last time and goes still."
    ],
    decay: [
      "A mist wraith turns to dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A mist wraith swings {weapon} at you!",
        "A mist wraith tries to ensnare you!"
      ],
      claw: [
        "A mist wraith claws at you!"
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
