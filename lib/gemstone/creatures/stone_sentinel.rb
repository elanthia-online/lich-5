{
  schema_version: 3,
  name: "stone sentinel",
  noun: "",
  url: "https://gswiki.play.net/stone_sentinel",
  picture: "",
  level: 53,
  family: "Golem",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Magical"
  ],
  bcs: true,
  max_hp: nil,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Darkstone Castle",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound",
        as: 380
      }
    ],
    bolt_spells: [
      {
        name: "Fireball",
        as: 373
      }
    ],
    warding_spells: [
      {
        name: "Mind Jolt",
        cs: (231..241)
      },
      {
        name: "Silence",
        cs: (231..241)
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Earthen Fury (917)"
      }
    ],
    maneuvers: [],
    special_abilities: [
      {
        name: "Stone-spitting"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "20",
    immunities: [
      "Stun"
    ],
    melee: nil,
    ranged: (63..103),
    bolt: nil,
    udf: (294..446),
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: (163..168),
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
    skin: "No",
    other: nil
  },
  messaging: {
    description: [
      "Comprised of solid blocks of granite, the immense stone sentinel stands and moves very stiffly. Each portion of its anatomy is chiseled in rectangular pieces with sharp right angles. It is not apparent how this animated construct moves, or how it even stays together, but somehow it does both effectively. The attacks of a stone sentinel carry the weight of tons of rock behind them. Being in the path of one is not an experience to be recommended."
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
