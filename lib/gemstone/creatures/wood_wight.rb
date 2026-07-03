{
  schema_version: 3,
  name: "wood wight",
  noun: "",
  url: "https://gswiki.play.net/wood_wight",
  picture: "",
  level: 20,
  family: "Wight",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 170,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Marshtown",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 156
      },
      {
        name: "Closed fist",
        as: 166
      },
      {
        name: "Pound",
        as: 146
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Mind Jolt (706)",
        cs: 123
      }
    ],
    offensive_spells: [
      {
        name: "Earthen Fury (917)"
      }
    ],
    maneuvers: [],
    special_abilities: [
      {
        name: "[[Gas cloud]]"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: 73,
    ranged: nil,
    bolt: 72,
    udf: 139,
    bar_td: 66,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 61,
    wiz_td: nil,
    mje_td: 62,
    mne_td: 63,
    mjs_td: nil,
    mns_td: 60,
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
    skin: "a wight scalp",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The wood wight stalks the forest, searching for  decaying and not-so-decaying flesh.  Perhaps once a powerful  human ranger, the wood wight is still powerful, but its tattered clothing is covered with mold, fungus and moss.  The wood wight shambles about, mercilessly attacking anything living.  Its cold, grey eyes and clammy fingers  wield magic and weaponry with equal skill.</pre>"
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
