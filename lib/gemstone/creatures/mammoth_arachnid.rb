{
  schema_version: 3,
  name: "mammoth arachnid",
  noun: "arachnid",
  url: "https://gswiki.play.net/mammoth_arachnid",
  picture: "",
  level: 30,
  family: "Arachnid",
  type: "Arachnid",
  undead: false,
  blood: true,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: false,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 350,
  speed: 8,
  height: 5,
  size: "large",
  areas: [
    {
      name: "Sorcerer's Isle",
      uids: [14202001..14202023]
    },
    {
      name: "Spider Temple",
      uids: [13020..13036]
    },
    {
      name: "unmapped",
      uids: [4217102..4217132]
    },
    {
      name: "Vornavian Coast",
      uids: [4218301..4218325]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (190..215)
      },
      {
        name: "Ensnare",
        as: (204..226)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Web"
      }
    ],
    special_abilities: [
      {
        name: "Web"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (103..289),
    ranged: (141..142),
    bolt: (141..142),
    udf: 188,
    bar_td: (90..96),
    cle_td: (87..96),
    emp_td: (88..97),
    pal_td: (87..96),
    ran_td: (87..96),
    sor_td: (89..101),
    wiz_td: nil,
    mje_td: (100..106),
    mne_td: (100..106),
    mjs_td: (104..114),
    mns_td: (104..114),
    mnm_td: 90,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye",
    "a bruised right eye",
    "a completely severed left foreleg",
    "a completely severed right foreleg"
  ],
  treasure: {
    coins: true,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a mammoth arachnid mandible",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The mammoth arachnid towers over its prey, fangs dripping poison mixed with fresh blood from its last kill shortly ago. Its entire body is draped with long, coal black hair, with the exception of a small patch on the very rear tip of its bulbous abdomen. This contains the spinnerets it uses to effectively web its prey before injecting the victim with a caustic poison, resulting in slow disintegration from the inside. The arachnid's eight crimson eyes dart about, making certain no prey, no matter how small, escapes."
    ],
    arrival: [],
    flee: [
      "A mammoth arachnid crawls {direction}.",
      "A mammoth arachnid scurries {direction}.",
      "A mammoth arachnid hobbles {direction}."
    ],
    death: [
      "The mammoth arachnid collapses to the ground and dies.",
      "The mammoth arachnid's body jerks one last time and dies."
    ],
    decay: [
      "A mammoth arachnid's legs shrivel up beneath it as it decays into dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A mammoth arachnid tries to ensnare {target}!"
      ],
      bite: [
        "A mammoth arachnid tries to bite you!"
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
