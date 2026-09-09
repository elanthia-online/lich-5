{
  schema_version: 3,
  name: "flayed gigas disciple",
  noun: "disciple",
  url: "https://gswiki.play.net/flayed_gigas_disciple",
  picture: "",
  level: 113,
  family: "Gigas",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 600,
  speed: 6,
  height: 30,
  size: "huge",
  areas: [
    {
      name: "Hinterwilds",
      uids: [7503401..7503421, 7503467..7503478, 7503490..7503498]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Gigantic hand",
        as: 597
      },
      {
        name: "Skinless fist down",
        as: 587
      }
    ],
    bolt_spells: [
      {
        name: "903",
        as: 521
      }
    ],
    warding_spells: [
      {
        name: "1115",
        cs: 521
      },
      {
        name: "719",
        cs: 535
      },
      {
        name: "Point",
        cs: 517
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Point"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: nil,
    ranged: (520..625),
    bolt: (520..625),
    udf: (537..718),
    bar_td: nil,
    cle_td: nil,
    emp_td: 504,
    pal_td: nil,
    ran_td: 454,
    sor_td: nil,
    wiz_td: nil,
    mje_td: (405..525),
    mne_td: (405..525),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a crude wooden cudgel",
    "a tattered hide cloak painted with dark sigils"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "ayanad crystal",
      "n'ayanad crystal",
      "petrified mammoth tusk"
    ],
    armaments: [
      "feras falchion",
      "drake greatsword",
      "feras mattock"
    ],
    transmogs: nil
  },
  messaging: {
    stun_break: [
      "A flayed gigas disciple shakes off the magic.",
      "A flayed gigas disciple rips free from {pronoun} slumber, lidless eyes going wide as if haunted by whatever nightmares lurked in {pronoun} sleep."
    ],
    attacks: {
      attack: [
        "A flayed gigas disciple attempts to stamp you out with one great foot!",
        "A flayed gigas disciple raises {pronoun} hand and conjures a fountain of steaming blood to gush at you!",
        "A flayed gigas disciple swings {weapon} at you!",
        "A flayed gigas disciple tries to strangle you with a gigantic hand!",
        "A flayed gigas disciple whirls into a deadly form, swinging a crude wooden cudgel at you!",
        "A flayed gigas disciple whirls into a deadly form, swinging a gnarled dark wooden crook adorned with sinuous patterns at you!"
      ],
      cast: [
        "A flayed gigas disciple points a flayed finger at {target}!"
      ]
    },
    stand: [
      "A flayed gigas disciple slams a single hand against the ground, leaving a wet red print. Strings of clotted shadow materialize out of thin air, lifting {pronoun} back into a standing position."
    ],
    description: [
      "A flayed gigas disciple is a hugely imposing figure. His monumental physique is all the more evident because his skin has been torn away, revealing wet and weeping tendons and raw muscle beneath. With no lips to conceal his teeth, the disciple appears to be ever grinning, but above his ruined nose are scarlet eyes ablaze with hateful zeal. A flayed gigas disciple wears a hooded shroud, ragged and threadbare, that is stained through with his own blood."
    ],
    arrival: [
      "A flayed gigas disciple just came through a break in the trees.",
      "A flayed gigas disciple just came through a pocked red stone arch.",
      "A flayed gigas disciple pounds in, {pronoun} eyes tight with restrained pain."
    ],
    flee: [
      "A flayed gigas disciple just went through a pair of colossal red stone pillars.",
      "A flayed gigas disciple pounds {direction}, ragged cloak flowing behind {pronoun}.",
      "A flayed gigas disciple just went through a ragged acid-pocked gash."
    ],
    death: [
      "A flayed gigas disciple goes limp as the last of {pronoun} energy is crushed from {pronoun} by {target} unyielding bearhug!",
      "The flayed gigas disciple slumps to the ground."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A flayed gigas disciple gestures with one bloody hand, chanting a sibilant prayer."
    ],
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
