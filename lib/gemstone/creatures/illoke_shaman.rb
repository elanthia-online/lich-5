{
  schema_version: 3,
  name: "illoke shaman",
  noun: "",
  url: "https://gswiki.play.net/illoke_shaman",
  picture: "",
  level: 67,
  family: "Giant",
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
  max_hp: 600,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Thanatoph",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "War mattock",
        as: (357..378)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Interdiction",
        cs: 282
      },
      {
        name: "Interference (212)",
        cs: 282
      }
    ],
    offensive_spells: [
      {
        name: "Earthen Fury"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16N",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: (244..259),
    cle_td: 265,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 268,
    mns_td: 261,
    mnm_td: nil,
    defensive_spells: [
      "Benediction (307)",
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Elemental Targeting (425)",
      "Resist Elements (602)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Glowing violet mote of essence"
  },
  messaging: {
    description: [
      "Massive and imposing, the Illoke shaman towers over adventurers. It is more than three times the size of the largest giantman, with smooth grey skin and deep black eyes that glare out from under a heavy brow. The eyes regard potential victims with disdain, as if they were nothing more than an offering to be sacrificed. Chiseled deep into the forehead of the shaman, the symbol of Illoke glows red with power."
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
