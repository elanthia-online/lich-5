{
  schema_version: 3,
  name: "large ogre",
  noun: "ogre",
  url: "https://gswiki.play.net/large_ogre",
  picture: "",
  level: 15,
  family: "Ogre",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 200,
  speed: 9,
  height: 9,
  size: "large",
  areas: [
    {
      name: "The Citadel",
      uids: [2100102..2100120]
    },
    {
      name: "Upper Trollfang",
      uids: [14001..14023]
    },
    {
      name: "Vornavian Coast",
      uids: [4218201..4218221]
    },
    {
      name: "Central Caravansary",
      uids: [4748001..4748007, 4748020..4748030]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 145
      },
      {
        name: "Closed fist",
        as: (130..155)
      },
      {
        name: "Flail",
        as: 165
      },
      {
        name: "Two-handed sword",
        as: 165
      },
      {
        name: "Mace",
        as: 155
      },
      {
        name: "Spear",
        as: 165
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
    asg: "location dependent",
    immunities: [],
    melee: (56..169),
    ranged: (43..91),
    bolt: (43..91),
    udf: (106..194),
    bar_td: 45,
    cle_td: (39..48),
    emp_td: (45..57),
    pal_td: (42..51),
    ran_td: (45..51),
    sor_td: (39..48),
    wiz_td: 45,
    mje_td: (42..48),
    mne_td: (42..48),
    mjs_td: (42..51),
    mns_td: (42..51),
    mnm_td: (39..45),
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
    "a spear",
    "a wooden shield",
    "some double chain",
    "some full leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "ogre tusk",
    other: "s'ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Even while slightly hunched over, the large ogre is taller than any giantman. Heavily muscled, his long arms hang nearly to the ground, ending in massive hands that easily crush anything unlucky enough to be in their grasp. The large ogre squints, as if barely able to see through his long, matted hair or extremely puzzled by the world around him. When standing downwind of this creature, it is evident that a bath is long overdue."
    ],
    arrival: [
      "A large ogre just arrived.",
      "A large ogre ambles in."
    ],
    flee: [
      "A large ogre runs {direction}.",
      "A large ogre limps {direction}."
    ],
    death: [
      "The large ogre screams one last time and dies.",
      "The large ogre falls to the ground and dies.",
      "The large ogre screams silently one last time and dies."
    ],
    decay: [
      "A large ogre decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      tackle: [
        "A large ogre hurls {reflexive} at {target}!"
      ],
      attack: [
        "A large ogre swings {weapon} at you!",
        "A large ogre thrusts with a spear at you!",
        "A large ogre swings a mace at {target}!",
        "A large ogre hunches down a bit and glares at you."
      ],
      hurl: [
        "A large ogre hurls {weapon} at {target}!"
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
