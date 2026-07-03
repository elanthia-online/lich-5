{
  schema_version: 3,
  name: "mist wraith",
  noun: "",
  url: "https://gswiki.play.net/mist_wraith",
  picture: "",
  level: 5,
  family: "Wraith",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 80,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Glaise Cnoc Cemetery",
      rooms: []
    },
    {
      name: "Cairnfang Forest",
      rooms: []
    },
    {
      name: "The Citadel",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 81
      },
      {
        name: "Claw",
        as: 71
      },
      {
        name: "Ensnare",
        as: 71
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
    melee: 10,
    ranged: nil,
    bolt: "-8",
    udf: 2,
    bar_td: 15,
    cle_td: 15,
    emp_td: nil,
    pal_td: 15,
    ran_td: 15,
    sor_td: 15,
    wiz_td: 15,
    mje_td: 15,
    mne_td: 15,
    mjs_td: 15,
    mns_td: 15,
    mnm_td: 15,
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
    skin: "mist wraith eye",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The smaller cousin to the normal lifeleeching wraith, the mist wraith is the spirit of a soldier vanquished in a great battle.  The spirits trap the mist of the local area and use it to give them a semi-physical form with which to exact vengeance.  This results in their powerful claws and arms with which to rip the living apart.</pre>"
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
