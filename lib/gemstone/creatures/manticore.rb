{
  schema_version: 3,
  name: "manticore",
  noun: "",
  url: "https://gswiki.play.net/manticore",
  picture: "",
  level: 9,
  family: "Chimeric",
  type: "Quadruped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 91,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Old Mine Road",
      rooms: []
    },
    {
      name: "Vornavian Coast",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 112
      },
      {
        name: "Closed fist",
        as: 122
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
    asg: "7N",
    immunities: [],
    melee: 40,
    ranged: (27..30),
    bolt: 27,
    udf: nil,
    bar_td: 27,
    cle_td: 27,
    emp_td: 27,
    pal_td: nil,
    ran_td: nil,
    sor_td: 27,
    wiz_td: nil,
    mje_td: 27,
    mne_td: 27,
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
    skin: "a manticore tail",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The first thing that strikes you about the manticore is its noxious smell.  At first it appears somewhat like an unkempt lion, but after you wipe away the tears brought to your eyes by its vile stench, you see that its head is more like that of a man, and it has a long segmented tail like that of a scorpion.</pre>\n\nThe manticore is large in size and about three feet high."
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
