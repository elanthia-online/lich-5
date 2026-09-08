{
  schema_version: 3,
  name: "black bear",
  noun: "bear",
  url: "https://gswiki.play.net/black_bear",
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
  max_hp: 210,
  speed: 14,
  height: 3,
  size: "large",
  areas: [
    {
      name: "Neartofar Forest",
      uids: [14015101..14015118]
    },
    {
      name: "Lysierian Hills",
      uids: [92002..92018]
    },
    {
      name: "Slope",
      uids: [395002..395015]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite (attack)",
        as: 180
      },
      {
        name: "Claw (attack)",
        as: 190
      },
      {
        name: "Charge (attack)",
        as: 190
      },
      {
        name: "Bite",
        as: 150
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
    special_abilities: [
      {
        name: "Pounce"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (92..152),
    ranged: (85..104),
    bolt: (85..104),
    udf: (116..160),
    bar_td: (48..54),
    cle_td: (45..54),
    emp_td: (48..56),
    pal_td: (42..54),
    ran_td: (45..54),
    sor_td: (45..54),
    wiz_td: nil,
    mje_td: 42,
    mne_td: 42,
    mjs_td: (45..48),
    mns_td: (45..48),
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
    skin: "a bear hide",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The black bear is a medium sized bear with a body about six feet long and appears to weigh around 440 pounds. Mostly blackish in color, asone would expect from a black bear, its muzzle is somewhat lighter and a distinct V-shaped patch of cream colored fur can be found on the chest. Also of note are the ears which appear much larger than those of other bears."
    ],
    arrival: [
      "A black bear lumbers in!",
      "A black bear lumbers noisily into the area drooling hungrily!"
    ],
    flee: [
      "A black bear lumbers {direction}.",
      "A black bear slowly lumbers {direction}, growling in pain."
    ],
    death: [
      "The black bear lets out a blood-curdling roar and dies.",
      "The black bear collapses heavily into a heap on the ground and dies."
    ],
    decay: [
      "A black bear decays into a compost of fangs, fur and claws."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      claw: [
        "A black bear claws at you!"
      ],
      bite: [
        "A black bear tries to bite you!"
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
