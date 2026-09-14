{
  schema_version: 3,
  name: "lesser ice giant",
  noun: "giant",
  url: "https://gswiki.play.net/lesser_ice_giant",
  picture: "",
  level: 41,
  family: "Giant",
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
    "Living",
    "Element-based"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: 15,
  size: "huge",
  areas: [
    {
      name: "Sleeping Lady Mountains",
      uids: [4560011..4560036]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Massive Icicle",
        as: 299
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "AS Booster"
      },
      {
        name: "Ground Slam"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (180..322),
    ranged: (184..339),
    bolt: (184..339),
    udf: (239..373),
    bar_td: (133..136),
    cle_td: (146..152),
    emp_td: (146..152),
    pal_td: (120..129),
    ran_td: (123..132),
    sor_td: (154..160),
    wiz_td: nil,
    mje_td: (162..165),
    mne_td: (162..165),
    mjs_td: (137..155),
    mns_td: (137..155),
    mnm_td: (114..123),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a fur-lined horned helm",
    "a massive icicle"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a giant scalp",
    other: "essence of water",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Standing twice as tall as the tallest giantman, the ice giant trails frost and snow in her wake. Seemingly carved from living ice and snow, icy blue eyes set beneath a heavily furrowed brow and a tangled mop of icy blue hair provide a splash of color against the ice giant's dull white frost-covered skin."
    ],
    arrival: [
      "A lesser ice giant lumbers in, followed by a hailing icestorm!"
    ],
    flee: [
      "A lesser ice giant lumbers {direction}, followed by a hailing icestorm."
    ],
    death: [
      "The ice giant cries out in cold agony one last time and dies.",
      "The ice giant falls to the ground motionless."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    stand: [
      "A lesser ice giant throws {pronoun} head back and howls, shaking off the stun!"
    ],
    attacks: {
      attack: [
        "A lesser ice giant swings {weapon} at you!"
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
