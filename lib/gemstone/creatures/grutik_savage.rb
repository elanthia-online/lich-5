{
  schema_version: 3,
  name: "grutik savage",
  noun: "savage",
  url: "https://gswiki.play.net/grutik_savage",
  picture: "",
  level: 27,
  family: "Grutik",
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
  max_hp: 298,
  speed: 11,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Zaerthu Tunnels",
      uids: [13009001..13009039]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Spear",
        as: (188..230)
      },
      {
        name: "Dart",
        as: 249
      },
      {
        name: "Closed fist",
        as: 200
      },
      {
        name: "Crude stone axe",
        as: 206
      },
      {
        name: "Crude wooden club",
        as: 215
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
    melee: (190..306),
    ranged: (167..218),
    bolt: (167..218),
    udf: (189..300),
    bar_td: 81,
    cle_td: (81..90),
    emp_td: (88..96),
    pal_td: (78..87),
    ran_td: (75..84),
    sor_td: 92,
    wiz_td: 96,
    mje_td: 96,
    mne_td: 96,
    mjs_td: (82..91),
    mns_td: (82..91),
    mnm_td: (81..84),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a crude stone axe",
    "a crude wooden club",
    "a crude wooden shield",
    "a crude wooden spear",
    "some crude leather armor"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Glimmering blue essence shard",
      "glimmering blue mote of essence"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "This misshapen humanoid has large luminous eyes from many years of living underground. It's dressed in scraps of leather armor and odd bits of mismatched clothing, apparently scavenged from various sources. The flesh you can see underneath is mostly grey though well muscled."
    ],
    arrival: [
      "A Grutik savage shambles in."
    ],
    flee: [
      "A Grutik savage shambles {direction}."
    ],
    death: [
      "A Grutik savage collapses into a lifeless heap upon the ground."
    ],
    decay: [
      "A Grutik savage collapses into a lifeless heap upon the ground.",
      "A Grutik savage's body turns to dust."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A grutik savage tries to shake off the stun."
    ],
    attacks: {
      attack: [
        "A Grutik savage swings {weapon} at you!",
        "A Grutik savage thrusts with a crude wooden spear at you!",
        "A Grutik savage shoots a tiny dart at you!",
        "A grutik savage shoots a tiny dart at you!",
        "A grutik savage thrusts with a crude wooden spear at you!",
        "A grutik savage swings a crude stone axe at you!",
        "A grutik savage swings a crude wooden club at you!"
      ],
      hurl: [
        "A Grutik savage throws a crude wooden club at you!",
        "A grutik savage throws a crude wooden club at you!"
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
