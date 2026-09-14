{
  schema_version: 3,
  name: "spectacled bear",
  noun: "bear",
  url: "https://gswiki.play.net/spectacled_bear",
  picture: "",
  level: nil,
  family: "Bear",
  type: "Quadruped",
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
  otherclass: [],
  bcs: true,
  max_hp: 212,
  speed: 14,
  height: 3,
  size: "large",
  areas: [
    {
      name: "Black Weald",
      uids: [7130001..7130018]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 180
      },
      {
        name: "Charge",
        as: 171
      },
      {
        name: "Claw",
        as: 171
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
    asg: nil,
    immunities: [],
    melee: (38..152),
    ranged: (-39..104),
    bolt: (-39..104),
    udf: (125..160),
    bar_td: nil,
    cle_td: (48..54),
    emp_td: (29..59),
    pal_td: (45..54),
    ran_td: (42..55),
    sor_td: (48..54),
    wiz_td: nil,
    mje_td: 48,
    mne_td: 48,
    mjs_td: (48..54),
    mns_td: (48..54),
    mnm_td: (45..54),
    defensive_spells: [],
    defensive_abilities: [],
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
    gems: nil,
    boxes: nil,
    skin: "hide",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      ""
    ],
    arrival: [
      "A spectacled bear lumbers in!",
      "A spectacled bear slowly lumbers in, growling in pain!",
      "A spectacled bear lumbers noisily into the area drooling hungrily!",
      "A spectacled bear shudders and lumbers in, snarling in agony!"
    ],
    flee: [
      "A spectacled bear lumbers {direction}.",
      "A spectacled bear slowly lumbers {direction}, growling in pain.",
      "A spectacled bear slowly backs away, {pronoun} teeth bared.",
      "A spectacled bear shudders and lumbers south, snarling in agony.",
      "A spectacled bear shudders and lumbers east, snarling in agony."
    ],
    death: [
      "The spectacled bear collapses heavily into a heap on the ground and dies.",
      "The spectacled bear lets out a blood-curdling roar and dies."
    ],
    decay: [
      "A spectacled bear decays into a compost of fangs, fur and claws."
    ],
    search: [
      "A spectacled bear sniffs the air carefully..",
      "A spectacled bear snuffles the ground a moment looking for something to eat.",
      "A spectacled bear discovers you in your hiding place!"
    ],
    spell_prep: [],
    attacks: {
      attack: [
        "A spectacled bear charges at you!",
        "A spectacled bear charges at you, but seeing {pronoun} coming, you acrobatically spring over the spectacled bear!",
        "A spectacled bear charges at {target}, but seeing {pronoun} coming, {target} acrobatically springs over the spectacled bear, inspiring you!",
        "A spectacled bear charges at you, but you move out of the way at the last second!",
        "A spectacled bear charges at you, but seeing {pronoun} coming, you acrobatically spring over the spectacled bear, inspiring everyone around you!"
      ],
      bite: [
        "A spectacled bear tries to bite you!"
      ],
      claw: [
        "A spectacled bear claws at you!"
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
