{
  schema_version: 3,
  name: "mountain ogre",
  noun: "",
  url: "https://gswiki.play.net/mountain_ogre",
  picture: "",
  level: 16,
  family: "Ogre",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 210,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Danjirland",
      rooms: []
    },
    {
      name: "Old Mine Road",
      rooms: []
    },
    {
      name: "Temple of Hope",
      rooms: []
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
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tackle"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "various",
    immunities: [],
    melee: (111..149),
    ranged: nil,
    bolt: 136,
    udf: nil,
    bar_td: 48,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 48,
    wiz_td: nil,
    mje_td: 48,
    mne_td: 48,
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
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an ogre nose",
    other: nil
  },
  messaging: {
    description: [
      "Nearly as big as a large boulder and as thick as the rock in one, the mountain ogre spends the majority of its time pounding around, killing, eating and sleeping, not necessarily in order of importance. Its skin is a blotchy mix of light brown and slate grey, much of which is hidden by its long, matted dirt-brown hair. A huge, protruding lower lip hides the pointed rending teeth of the mountain ogre, and its claws are kept nicely sharpened by constant dragging over the hard rock surfaces."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
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
