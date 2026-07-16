{
  schema_version: 3,
  name: "lesser faeroth",
  noun: "",
  url: "https://gswiki.play.net/lesser_faeroth",
  picture: "",
  level: 46,
  family: "Faeroth",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Gyldemar Forest",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (271..281)
      },
      {
        name: "Claw",
        as: (281..291)
      },
      {
        name: "Pound",
        as: (271..281)
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
    asg: "8N",
    immunities: [],
    melee: 208,
    ranged: (205..216),
    bolt: 229,
    udf: nil,
    bar_td: (143..153),
    cle_td: 158,
    emp_td: (157..166),
    pal_td: nil,
    ran_td: 138,
    sor_td: 166,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 175,
    mjs_td: (157..166),
    mns_td: (157..166),
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
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: nil,
    other: "a mottled faeroth crest"
  },
  messaging: {
    description: [
      "The lesser faeroth looks as though she is a near relative to a monkey. Standing on powerful forelimbs, her body is lifted entirely off the ground. Two atrophied legs with filthy claws dangle loosely below the body and look to be double-jointed. A spark of malevolent intelligence burns in her eyes."
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
