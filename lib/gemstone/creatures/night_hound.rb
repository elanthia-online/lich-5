{
  schema_version: 3,
  name: "night hound",
  noun: "",
  url: "https://gswiki.play.net/night_hound",
  picture: "",
  level: 24,
  family: "Canine",
  type: "Quadruped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 210,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Graveyard",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 192
      },
      {
        name: "Claw",
        as: 202
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Breath attack"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: 105,
    ranged: nil,
    bolt: 143,
    udf: nil,
    bar_td: 97,
    cle_td: 99,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 104,
    wiz_td: nil,
    mje_td: 106,
    mne_td: (101..107),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: 97,
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
    skin: "a night hound hide",
    other: "No"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>You have never seen anything quite like a night hound, so you are not really sure what to make of it or how dangerous it might be.</pre>"
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
