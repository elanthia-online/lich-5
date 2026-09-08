{
  schema_version: 3,
  name: "greater ice giant",
  noun: "giant",
  url: "https://gswiki.play.net/greater_ice_giant",
  picture: "",
  level: 46,
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
  height: 20,
  size: "huge",
  areas: [
    {
      name: "Sleeping Lady Mountains",
      uids: [4560030..4560053]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Battle-axe",
        as: (236..306)
      }
    ],
    bolt_spells: [
      {
        name: "Major Cold (907)",
        as: 215
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Spirit Dispel"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (156..305),
    ranged: (167..189),
    bolt: (167..189),
    udf: (248..289),
    bar_td: (151..156),
    cle_td: (165..175),
    emp_td: (164..174),
    pal_td: (139..149),
    ran_td: (149..158),
    sor_td: (175..184),
    wiz_td: nil,
    mje_td: (180..189),
    mne_td: (180..189),
    mjs_td: (164..174),
    mns_td: (164..174),
    mnm_td: (147..156),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a frost-covered battle-axe"
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
      "Standing nearly three times as tall as a giantman, the ice giant trails frost and snow in his wake. Seemingly carved from living ice and snow, icy blue eyes set beneath a heavily furrowed brow and a tangled mop of icy blue hair provide a splash of color against the ice giant's dull white frost-covered skin."
    ],
    arrival: [
      "A greater ice giant lumbers in, followed by a hailing icestorm!"
    ],
    flee: [
      "A greater ice giant lumbers {direction}, followed by a hailing icestorm!",
      "A greater ice giant lumbers {direction}, followed by a hailing icestorm."
    ],
    death: [
      "The ice giant cries out in cold agony one last time and dies.",
      "The ice giant falls to the ground motionless."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A greater ice giant mutters an incantation."
    ],
    stand: [
      "A greater ice giant throws {pronoun} head back and howls, shaking off the stun!"
    ],
    attacks: {
      attack: [
        "A greater ice giant swings {weapon} at you!"
      ],
      cast: [
        "A greater ice giant points an icy finger at you!"
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
