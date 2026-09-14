{
  schema_version: 3,
  name: "steam dervish",
  noun: "dervish",
  url: "https://gswiki.play.net/steam_dervish",
  picture: "",
  level: 84,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: false,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Element-based",
    "Magical"
  ],
  bcs: true,
  max_hp: 300,
  speed: 5,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "McKyren's End",
      uids: [3063001..3063013]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Longsword",
        as: (402..452)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Hamstring"
      },
      {
        name: "Steam Blast"
      }
    ],
    special_abilities: [
      {
        name: "Steam blast"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "16",
    immunities: [],
    melee: (223..487),
    ranged: (215..379),
    bolt: (215..379),
    udf: (493..561),
    bar_td: (325..349),
    cle_td: 335,
    emp_td: (318..321),
    pal_td: (272..281),
    ran_td: (278..287),
    sor_td: (329..343),
    wiz_td: nil,
    mje_td: (367..370),
    mne_td: (367..370),
    mjs_td: (321..328),
    mns_td: (321..328),
    mnm_td: (252..255),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a dripping glaes chain hauberk",
    "a steaming glaes longsword",
    "a warped glaes buckler"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Essence of water",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "This wiry humanoid resembles a gaunt human with badly blistered and burnt skin. In the place of eyes, two steaming holes glower with malevolent intent. A persistent cloud of steam emanates from the steam dervish, extending an aura of oppressive humidity around her."
    ],
    arrival: [],
    flee: [],
    death: [
      "The steam dervish falls to the ground, leaking steam profusely.",
      "The steam dervish fumes with rage as she crumples to the ground!  Hot steam sprays out from her severed right leg thrashing on the ground!",
      "The steam dervish fumes with rage as he crumples to the ground!  Hot steam sprays out from his severed left leg thrashing on the ground!",
      "The steam dervish exhales {pronoun} last breath directly at you!"
    ],
    decay: [
      "Thin blue lines of magical energy crackle over the body of a phantasmal bestial swordsman before he dissolves, leaving a puddle of liquid and the smell of ozone in the air.",
      "The thick skin of a minotaur warrior falls in upon itself as his enormous form decays into a fine dust.",
      "A steam dervish evaporates away."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A steam dervish swings {weapon} at you!"
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
