{
  schema_version: 3,
  name: "darken",
  noun: "darken",
  url: "https://gswiki.play.net/darken",
  picture: "",
  level: 28,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "non-corporeal undead"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Wraithenmist",
      uids: [13027003..13027083]
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
    asg: "8N",
    immunities: [],
    melee: 127,
    ranged: nil,
    bolt: nil,
    udf: (162..176),
    bar_td: 87,
    cle_td: 97,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 97,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 101,
    mjs_td: nil,
    mns_td: 93,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [
      {
        name: "invisibility",
        note: "naturally invisible; requires 109 or 205 to reveal"
      }
    ],
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
      "As if the shadows themselves had come alive, two swirling red eyes stare at you from a vaguely humanoid shape. The body of the darken seems to shift and meld into the shadows. Small writhing tendrils of shadow seem to snake from the darken's shape, searching along the ground for something."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [
      "A darken melts into the shadows heading southwestward.",
      "A darken melts into the shadows heading westward.",
      "A darken melts into the shadows heading northeastward.",
      "A darken melts into the shadows heading eastward.",
      "A darken melts into the shadows heading southeastward."
    ],
    search: [],
    spell_prep: [],
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
