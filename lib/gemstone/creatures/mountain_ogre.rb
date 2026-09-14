{
  schema_version: 3,
  name: "mountain ogre",
  noun: "ogre",
  url: "https://gswiki.play.net/mountain_ogre",
  picture: "",
  level: 16,
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
  max_hp: 210,
  speed: 11,
  height: 8,
  size: "large",
  areas: [
    {
      name: "Upper Trollfang",
      uids: [17101..17118]
    },
    {
      name: "Abbey",
      uids: [4132001..4132010]
    },
    {
      name: "Liath Bheinn and Aillidh Brae",
      uids: [4250050..4250060]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "War mattock",
        as: 173
      },
      {
        name: "Broadsword",
        as: 173
      },
      {
        name: "Crude pine mattock",
        as: 177
      },
      {
        name: "Cudgel",
        as: 177
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
    asg: "various",
    immunities: [],
    melee: (109..201),
    ranged: (90..136),
    bolt: (90..136),
    udf: (125..230),
    bar_td: 48,
    cle_td: (42..51),
    emp_td: (48..56),
    pal_td: (45..48),
    ran_td: (45..54),
    sor_td: (45..54),
    wiz_td: nil,
    mje_td: 48,
    mne_td: 48,
    mjs_td: (45..54),
    mns_td: (45..54),
    mnm_td: (48..54),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a crude pine mattock",
    "a cudgel",
    "some full leather",
    "some unevenly stitched pale leathers"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an ogre nose",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Nearly as big as a large boulder and as thick as the rock in one, the mountain ogre spends the majority of its time pounding around, killing, eating and sleeping, not necessarily in order of importance. Its skin is a blotchy mix of light brown and slate grey, much of which is hidden by its long, matted dirt-brown hair. A huge, protruding lower lip hides the pointed rending teeth of the mountain ogre, and its claws are kept nicely sharpened by constant dragging over the hard rock surfaces."
    ],
    arrival: [
      "A mountain ogre just arrived."
    ],
    flee: [
      "A mountain ogre runs {direction}.",
      "A mountain ogre limps {direction}."
    ],
    death: [
      "The mountain ogre falls to the ground and dies.",
      "The mountain ogre screams one last time and dies.",
      "The mountain ogre screams silently one last time and dies."
    ],
    decay: [
      "A mountain ogre decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A mountain ogre swings {weapon} at you!",
        "A mountain ogre swings a crude pine mattock at {target}!",
        "A mountain ogre throws {pronoun} head back with a vicious roar!",
        "A mountain ogre swings a cudgel at {target}!",
        "A mountain ogre throws {pronoun} head back and laughs hysterically."
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
