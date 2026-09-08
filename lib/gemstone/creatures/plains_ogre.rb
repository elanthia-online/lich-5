{
  schema_version: 3,
  name: "plains ogre",
  noun: "ogre",
  url: "https://gswiki.play.net/plains_ogre",
  picture: "",
  level: 17,
  family: "Ogre",
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
    "Living"
  ],
  bcs: true,
  max_hp: 220,
  speed: nil,
  height: 9,
  size: "large",
  areas: [
    {
      name: "Grasslands",
      uids: [14012100..14012120, 14012150..14012165]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 165
      },
      {
        name: "Mace",
        as: (157..175)
      },
      {
        name: "Claw",
        as: 155
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tackle"
      },
      {
        name: "Pounce"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6",
    immunities: [],
    melee: (68..158),
    ranged: (57..95),
    bolt: (57..95),
    udf: (124..205),
    bar_td: 51,
    cle_td: (45..54),
    emp_td: (51..59),
    pal_td: (48..57),
    ran_td: (48..57),
    sor_td: (45..54),
    wiz_td: nil,
    mje_td: 51,
    mne_td: 51,
    mjs_td: (48..54),
    mns_td: (48..54),
    mnm_td: (51..57),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a mace",
    "some full leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an ogre nose",
    other: [
      "ayanad crystal",
      "s'ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Even while slightly hunched over, the plains ogre is taller than any giantman. Long-limbed and lithe for rapid travel over the plains, his body is the antithesis of most of his cousins. The one exception is in his massive hands that can easily crush anything unlucky enough to be in caught in their grasp. The plains ogre's face is pinched in a permanent squint from countless hours out on the sun-baked plains. When standing downwind of this creature, it is evident that he is in much need of a bath."
    ],
    arrival: [
      "A plains ogre just arrived."
    ],
    flee: [
      "A plains ogre runs {direction}.",
      "A plains ogre limps {direction}."
    ],
    death: [
      "The plains ogre screams one last time and dies.",
      "The plains ogre falls to the ground and dies.",
      "The plains ogre screams silently one last time and dies."
    ],
    decay: [
      "A plains ogre decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A plains ogre swings {weapon} at you!",
        "A plains ogre swings a mace at {target}!"
      ],
      claw: [
        "A plains ogre claws at you!"
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
