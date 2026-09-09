{
  schema_version: 3,
  name: "arachne acolyte",
  noun: "acolyte",
  url: "https://gswiki.play.net/arachne_acolyte",
  picture: "",
  level: 23,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 190,
  speed: 8,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Spider Temple",
      uids: [13010..13030]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "War hammer",
        as: 161
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Frenzy (216)",
        cs: 118
      },
      {
        name: "Web (118)",
        cs: 118
      }
    ],
    offensive_spells: [
      {
        name: "Spirit Strike (117)"
      }
    ],
    maneuvers: [
      {
        name: "Disarm"
      },
      {
        name: "Tackle"
      },
      {
        name: "Pounce"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16",
    immunities: [],
    melee: (98..246),
    ranged: (49..199),
    bolt: (49..199),
    udf: (132..245),
    bar_td: 67,
    cle_td: (76..82),
    emp_td: (70..80),
    pal_td: (63..82),
    ran_td: (72..82),
    sor_td: 57,
    wiz_td: (67..72),
    mje_td: (67..73),
    mne_td: (67..73),
    mjs_td: (66..104),
    mns_td: (66..104),
    mnm_td: (76..81),
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)",
      "Spirit Fog (106)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a chain hauberk",
    "a war hammer",
    "a wooden shield"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "glimmering blue essence shard",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The Arachne acolyte's head is clean shaven and bald. Where hair once grew, ornate tattoos of deep red hue decorate every visible bare body part. The Arachne acolytes are muscular but lean. Long years of study and training has produced fanatical allegiance to Arachne. Any semblance of humanity has long since been exorcised through torture and meditation. Only the zealous duty of Arachne now compels their existence."
    ],
    arrival: [
      "An Arachne acolyte just arrived.",
      "An Arachne acolyte rushes in glowering insidiously!"
    ],
    flee: [
      "An Arachne acolyte winces and anxiously retreats!",
      "An Arachne acolyte heads {direction}.",
      "An Arachne acolyte limps {direction}."
    ],
    death: [
      "The Arachne acolyte slumps to the ground and dies.",
      "The Arachne acolyte exhales a final curse and dies."
    ],
    decay: [
      "The Arachne acolyte's body dissolves into a puff of lingering red smoke."
    ],
    search: [],
    spell_prep: [
      "An Arachne acolyte utters a phrase of magic.",
      "An Arachne acolyte mutters sullenly!",
      "An Arachne acolyte chants aloud, \"Arachne is my saviour! Arachne is my purpose!\""
    ],
    attacks: {
      attack: [
        "An Arachne acolyte swings {weapon} at you!",
        "An arachne acolyte rushes in glowering insidiously!",
        "An arachne acolyte swings a war hammer at you!",
        "An arachne acolyte glowers at you!"
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
