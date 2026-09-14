{
  schema_version: 3,
  name: "forest trali shaman",
  noun: "shaman",
  url: "https://gswiki.play.net/forest_trali_shaman",
  picture: "",
  level: 46,
  family: "Trali",
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
  boss_type: "miniboss",
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 238,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Gyldemar Forest",
      uids: [13028038..13028080]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Mace",
        as: 271
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Bind (214)",
        cs: 224
      },
      {
        name: "Calm (201)"
      },
      {
        name: "Silence (210)"
      },
      {
        name: "Unbalance (110)"
      }
    ],
    offensive_spells: [
      {
        name: "Phoen's Strength (606)"
      },
      {
        name: "Spirit Strike (117)"
      },
      {
        name: "Spike Thorn (616)"
      }
    ],
    maneuvers: [
      {
        name: "Gesture"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "9",
    immunities: [],
    melee: (197..318),
    ranged: (186..275),
    bolt: (186..275),
    udf: (301..374),
    bar_td: (149..172),
    cle_td: (162..171),
    emp_td: (164..170),
    pal_td: (145..155),
    ran_td: (145..155),
    sor_td: (171..193),
    wiz_td: nil,
    mje_td: (198..200),
    mne_td: (198..200),
    mjs_td: (170..183),
    mns_td: (170..183),
    mnm_td: (163..166),
    defensive_spells: [
      "Natural Colors (601)",
      "Spirit Defense (103)",
      "Spirit Shield (202)",
      "Spell Shield (219)",
      "Spirit Warding I (101)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a battered breastplate",
    "a battered shield",
    "a carved wooden talisman",
    "a metal-banded mace",
    "a smooth wooden talisman"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a trali scalp",
    other: [
      "Glowing violet essence dust",
      "glowing violet essence shard"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Standing nearly six feet tall, the man-like trali shaman watches adventurers' every move with piercing grey eyes. A short matted, reddish grey mane covers his head and his skin has a greenish grey hue. There is little doubt that the stealthy trali shaman can be a formidable opponent when need arises, or when he is hard pressed."
    ],
    arrival: [
      "A forest trali shaman arrives, sniffing the air for prey!",
      "A forest trali shaman stalks in.",
      "A forest trali shaman limps into the area."
    ],
    flee: [
      "A forest trali shaman skulks {direction}.",
      "A forest trali shaman limps {direction}."
    ],
    death: [
      "A forest trali shaman collapses upon the ground and the life fades from {pronoun} eyes.",
      "A forest trali shaman collapses upon the floor and the life fades from {pronoun} eyes."
    ],
    decay: [
      "A forest trali shaman's body crumbles into dust and is scattered by a stiff breeze."
    ],
    search: [],
    spell_prep: [
      "A forest trali shaman closes {pronoun} eyes, clutches {pronoun} talisman and begins chanting.",
      "A forest trali shaman chants, \"Laag O'mahn, saaf zris hatan!\"",
      "A forest trali shaman chants, \"Wraatk o'mahnes var tik frarat, surot E an pratka!\"",
      "A forest trali shaman chants, \"Laag O'mahn, hodt zris hatan os usk mah smat tik kraat var u!\"",
      "A forest trali shaman gestures and mutters a hurried chant. After a moment, {pronoun} looks somewhat better.",
      "A forest trali shaman closes {pronoun} eyes and concentrates, trying to regain control of {pronoun} senses."
    ],
    attacks: {
      attack: [
        "A forest trali shaman swings {weapon} at you!",
        "A forest trali shaman opens {pronoun} eyes and gestures sharply at you!"
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
