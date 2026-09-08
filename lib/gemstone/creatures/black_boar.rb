{
  schema_version: 3,
  name: "black boar",
  noun: "boar",
  url: "https://gswiki.play.net/black_boar",
  picture: "",
  level: 14,
  family: "Suine",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
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
  max_hp: 130,
  speed: nil,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Neartofar Forest",
      uids: [14015101..14015118]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (153..171)
      },
      {
        name: "Charge (attack)",
        as: 181
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
    special_abilities: [
      {
        name: "Charge"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "1",
    immunities: [],
    melee: (56..124),
    ranged: (53..73),
    bolt: (53..73),
    udf: (86..134),
    bar_td: 42,
    cle_td: 42,
    emp_td: (38..46),
    pal_td: (39..48),
    ran_td: (42..48),
    sor_td: (42..48),
    wiz_td: nil,
    mje_td: nil,
    mne_td: (36..42),
    mjs_td: (42..48),
    mns_td: (42..48),
    mnm_td: (39..48),
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
    skin: "a black boar hide",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The black boar snorts and snuffles at the ground, peering around with his close-set, bloodshot eyes in hopes of finding a target for his anger and aggression. Any who get in his way will most likely rapidly regret having done so. His body is covered with coarse, black hair, and yellowed tusks protrude from each side of his gaping mouth. Larger than most men, he is a good six feet long from dripping snout to curly tail and weighs more than a quarter ton. When in motion, the black boar moves with a surprising speed and dexterity for a beast his size. It is not unusual to find oneself snacked by this beast if not properly prepared."
    ],
    arrival: [
      "A black boar barrels in!",
      "A black boar crashes into view!"
    ],
    flee: [
      "A black boar grunts and barrels {direction}."
    ],
    death: [
      "The black boar lets out a final agonized squeal and dies.",
      "The black boar collapses to the ground, emits a final squeal, and dies.",
      "The black boar silently lets out a final agonized squeal and dies."
    ],
    decay: [
      "A black boar decays into a pile of fur and bone."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      bite: [
        "A black boar tries to bite you!"
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
