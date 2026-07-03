{
  schema_version: 3,
  name: "troll wraith",
  noun: "",
  url: "https://gswiki.play.net/troll_wraith",
  picture: "",
  level: 35,
  family: "Troll",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Non-corporeal undead",
    "Boss"
  ],
  bcs: nil,
  max_hp: nil,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Troll Burial Grounds",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 215
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
    asg: nil,
    immunities: [],
    melee: nil,
    ranged: 118,
    bolt: 105,
    udf: nil,
    bar_td: (118..123),
    cle_td: 130,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: (143..148),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense III (414)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: nil,
    other: "Glowing Violet Essence Dust,"
  },
  messaging: {
    description: [
      "A sickly, ebony mist encircles the troll wraith, obscuring the entire lower portion of the wraith, if there was one. Brilliant, platinum-hued orbs suspend in the air where the wraith's eyes once resided. The only true evidence of the wraith's former life are remnants of blackened steel gauntlets protecting the hands with only a few boney fingers being exposed."
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
