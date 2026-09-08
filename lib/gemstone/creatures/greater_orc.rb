{
  schema_version: 3,
  name: "greater orc",
  noun: "orc",
  url: "https://gswiki.play.net/greater_orc",
  picture: "",
  level: 8,
  family: "Orc",
  type: "Biped",
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
  max_hp: 112,
  speed: 15,
  height: 7,
  size: "medium",
  areas: [
    {
      name: "The Citadel",
      uids: [2100102..2100120]
    },
    {
      name: "Upper Trollfang",
      uids: [16001..16044]
    },
    {
      name: "Foothills of Zeltoph",
      uids: [2131001..2131010, 2131040..2131045]
    },
    {
      name: "Vornavian Coast",
      uids: [4214101..4214115]
    },
    {
      name: "Cairnfang",
      uids: [4745001..4745019, 4745021..4745032, 4745035..4745039]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Spear",
        as: 126
      },
      {
        name: "War mattock",
        as: 113
      },
      {
        name: "Mace",
        as: 113
      },
      {
        name: "Scimitar",
        as: 113
      },
      {
        name: "Short sword",
        as: 113
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
    asg: "varies",
    immunities: [],
    melee: (55..177),
    ranged: (46..83),
    bolt: (46..83),
    udf: (69..155),
    bar_td: 24,
    cle_td: 24,
    emp_td: 24,
    pal_td: (21..24),
    ran_td: 24,
    sor_td: 24,
    wiz_td: nil,
    mje_td: 24,
    mne_td: 24,
    mjs_td: 24,
    mns_td: 24,
    mnm_td: 24,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a chain hauberk",
    "a mace",
    "a scimitar",
    "a short sword",
    "a war mattock",
    "a wooden shield",
    "some cuirbouilli leather",
    "some double chain",
    "some double leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an orc scalp",
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Taller than a human and of substantially heavier build, the greater orc is a solid mass of bone and gristle. Red-rimmed eyes glare angrily out from under a thick bony forehead. Irregular clumps of rank hair cover its body and head. Its arms resemble thick and twisted tree trunks, ending in ragged claws crusted with dried gore."
    ],
    arrival: [
      "A greater orc stalks in!"
    ],
    flee: [
      "A greater orc stalks {direction}.",
      "A greater orc hobbles slowly {direction}, uttering a curse under {pronoun} breath.",
      "A greater orc hobbles {direction}, uttering a curse under {pronoun} breath!"
    ],
    death: [
      "A greater orc breathes {pronoun} last gasp and dies.",
      "A greater orc collapses into a pile of dust."
    ],
    decay: [
      "A greater orc collapses into a pile of dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A greater orc swings {weapon} at you!",
        "A greater orc swings a war mattock at {target}!",
        "A greater orc thrusts with a spear at {target}!",
        "A greater orc rushes forward and then at the last moment skids to a stop.",
        "A greater orc swings a mace at {target}!",
        "A greater orc swings a short sword at {target}!",
        "A greater orc hunches {pronoun} shoulders and glares at you."
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
