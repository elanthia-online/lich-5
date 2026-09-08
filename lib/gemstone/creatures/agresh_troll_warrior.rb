{
  schema_version: 3,
  name: "Agresh troll warrior",
  noun: "warrior",
  url: "https://gswiki.play.net/agresh_troll_warrior",
  picture: "",
  level: 16,
  family: "Troll",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 210,
  speed: 9,
  height: 8,
  size: "large",
  areas: [
    {
      name: "Grasslands",
      uids: [14012010..14012022]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "War hammer",
        as: 165
      },
      {
        name: "Fist",
        as: 115
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
    asg: "16",
    immunities: [],
    melee: (46..156),
    ranged: (26..100),
    bolt: (26..100),
    udf: (105..173),
    bar_td: 55,
    cle_td: 63,
    emp_td: 63,
    pal_td: (60..63),
    ran_td: 63,
    sor_td: 59,
    wiz_td: 55,
    mje_td: (55..59),
    mne_td: (55..59),
    mjs_td: 63,
    mns_td: 63,
    mnm_td: (48..55),
    defensive_spells: [
      "Spirit Warding II (107)"
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
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The troll warrior stands silenty still. Disdain touches its face as it awaits any who would challenge its bulking muscles. Stripes of ash run down its cheeks in illegible runes as bits of its straggly hair blow in front of it. The eyes that stare out from under its low brow are those of a natural born killer awaiting its next victim."
    ],
    arrival: [
      "An Agresh troll warrior just arrived!"
    ],
    flee: [
      "An Agresh troll warrior runs {direction}.",
      "An Agresh troll warrior limps {direction}."
    ],
    death: [],
    decay: [
      "An Agresh troll warrior decays into compost."
    ],
    search: [],
    spell_prep: [
      "An Agresh troll warrior mutters, \"Srlarloror'rt srar 'mrosrdnragh srar 'r'rar s'r'vr'r'rawrd!\""
    ],
    attacks: {
      attack: [
        "An Agresh troll warrior pounds at you with {pronoun} fist!",
        "An Agresh troll warrior swings {weapon} at you!"
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
