{
  schema_version: 3,
  name: "Agresh bear",
  noun: "bear",
  url: "https://gswiki.play.net/agresh_bear",
  picture: "",
  level: 16,
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
  max_hp: 212,
  speed: 12,
  height: 4,
  size: "large",
  areas: [
    {
      name: "Grasslands",
      uids: [14012050..14012070]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (144..179)
      },
      {
        name: "Bite",
        as: 174
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
    asg: "12N",
    immunities: [],
    melee: (96..168),
    ranged: (91..108),
    bolt: (91..108),
    udf: (125..164),
    bar_td: 48,
    cle_td: (48..54),
    emp_td: (48..56),
    pal_td: (42..48),
    ran_td: (48..54),
    sor_td: (42..53),
    wiz_td: nil,
    mje_td: 48,
    mne_td: 48,
    mjs_td: (45..51),
    mns_td: (45..51),
    mnm_td: (48..54),
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
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "an Agresh bear claw",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    attacks: {
      claw: [
        "An Agresh bear claws at you!"
      ],
      bite: [
        "An Agresh bear tries to bite you!"
      ]
    },
    stand: [
      "An Agresh bear stands up and growls!"
    ],
    description: [
      "The Agresh bear is all muscle and bone and presents a formidable appearance when standing on his hindlegs. He is a tawny gold in color allowing him to blend more easily into his surroundings or at least as much as a 600 pound bear can. The deadly claws that tip each front paw completes the total package of death known as the Agresh bear."
    ],
    arrival: [
      "An Agresh bear lumbers in, flecks of drool flinging with each of its strides.",
      "An Agresh bear lumbers in!"
    ],
    flee: [
      "An Agresh bear lumbers {direction}.",
      "An Agresh bear slowly lumbers {direction}, growling in pain.",
      "An Agresh bear slowly backs away, {pronoun} teeth bared.",
      "An Agresh bear lumbers {direction}, flecks of drool flinging with each of {pronoun} strides."
    ],
    death: [
      "The Agresh bear collapses heavily into a heap on the ground and dies.",
      "The Agresh bear lets out a blood-curdling roar and dies."
    ],
    decay: [
      "An Agresh bear decays into a compost of fangs, fur and claws."
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
