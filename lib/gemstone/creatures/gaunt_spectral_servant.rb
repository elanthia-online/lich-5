{
  schema_version: 3,
  name: "gaunt spectral servant",
  noun: "servant",
  url: "https://gswiki.play.net/gaunt_spectral_servant",
  picture: "",
  level: 44,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Marsh Keep",
      uids: [376001..376001, 376003..376010, 376015..376018, 376020..376034, 376040..376044, 376051..376054, 376057..376062, 376084..376088]
    },
    {
      name: "unmapped",
      uids: [376002..376002, 376019..376019, 376035..376039, 376055..376056]
    }
  ],
  attack_attributes: {
    physical_attacks: [],
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
    melee: (174..269),
    ranged: (189..232),
    bolt: (189..232),
    udf: (268..303),
    bar_td: nil,
    cle_td: (201..211),
    emp_td: (211..217),
    pal_td: (190..193),
    ran_td: 193,
    sor_td: 222,
    wiz_td: nil,
    mje_td: (435..560),
    mne_td: (435..560),
    mjs_td: (217..227),
    mns_td: (217..227),
    mnm_td: (150..157),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a crooked willow runestaff",
    "some threadbare patched cotton robes"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Glowing violet mote of essence",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The spectral servant silently floats several inches above the ground. His eyes gaze downward submissively as his gaunt form, dressed in the ragged remains of livery, waivers in and out of visibility. Scabs and open sores cover his features, while patches of transparent hair fall from his skull, vanishing into the air at his feet."
    ],
    arrival: [],
    flee: [
      "A gaunt spectral servant silently floats {direction}."
    ],
    death: [
      "A low sigh fills the air and the spectral servant fades to nothing."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A gaunt spectral servant whispers haunting arcane words that echo eerily."
    ],
    attacks: {
      attack: [
        "A gaunt spectral servant swings a crooked willow runestaff at you!",
        "A gaunt spectral servant weakly points at you!"
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
