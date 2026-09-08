{
  schema_version: 3,
  name: "grizzly bear",
  noun: "bear",
  url: "https://gswiki.play.net/grizzly_bear",
  picture: "",
  level: 38,
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
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 400,
  speed: 10,
  height: 4,
  size: "large",
  areas: [
    {
      name: "Pinefar Forests",
      uids: [4563014..4563026]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge",
        as: 286
      },
      {
        name: "Claw",
        as: (242..285)
      },
      {
        name: "Bite",
        as: 269
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Charge"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (205..254),
    ranged: (123..184),
    bolt: (123..184),
    udf: (211..291),
    bar_td: 114,
    cle_td: (123..132),
    emp_td: (124..133),
    pal_td: (111..120),
    ran_td: (114..117),
    sor_td: (130..137),
    wiz_td: nil,
    mje_td: 138,
    mne_td: 138,
    mjs_td: (124..130),
    mns_td: (124..130),
    mnm_td: (111..120),
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
    skin: "a grizzly bear hide",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    attacks: {
      attack: [
        "A grizzly bear charges at you!",
        "A grizzly bear charges at you, but seeing {pronoun} coming, you acrobatically spring over the grizzly bear!"
      ],
      bite: [
        "A grizzly bear tries to bite you!"
      ],
      claw: [
        "A grizzly bear claws at you!"
      ]
    },
    stand: [
      "A grizzly bear stands up on {pronoun} hind legs and roars!"
    ],
    description: [
      "One of the largest of the bears, the grizzly bear weighs around 860 pounds and has about ten feet of total body length. This bear is dark brown in color. The tips of her guard hairs are white, giving the bear a grizzled appearance. The grizzly bear has a characteristic muscle hump over the shoulders, and longer claws on her front paws than on her rear paws."
    ],
    arrival: [
      "A grizzly bear lumbers in!",
      "A grizzly bear shudders and lumbers in, snarling in agony!",
      "A grizzly bear lumbers noisily into the area drooling hungrily!"
    ],
    flee: [
      "A grizzly bear lumbers {direction}.",
      "A grizzly bear slowly backs away, {pronoun} teeth bared."
    ],
    death: [
      "The grizzly bear lets out a blood-curdling roar and dies.",
      "The grizzly bear collapses heavily into a heap on the ground and dies."
    ],
    decay: [
      "A grizzly bear decays into a compost of fangs, fur and claws."
    ],
    search: [
      "A grizzly bear snuffles the ground hungrily."
    ],
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
