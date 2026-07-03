{
  schema_version: 3,
  name: "pale crab",
  noun: "",
  url: "https://gswiki.play.net/pale_crab",
  picture: "",
  level: 2,
  family: "Crab",
  type: "Crustacean",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 36,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Coastal Cliffs",
      rooms: []
    },
    {
      name: "River Tunnels",
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
        as: 43
      },
      {
        name: "Ensnare",
        as: 43
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
    asg: "1N",
    immunities: [],
    melee: 27,
    ranged: 49,
    bolt: 24,
    udf: nil,
    bar_td: 6,
    cle_td: nil,
    emp_td: 6,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 6,
    mne_td: 6,
    mjs_td: 6,
    mns_td: 6,
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
    boxes: false,
    skin: "pale crab pincer",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The giant pale crab is about a foot across and has large pincers at the end of each of its two arms.  Its multiple legs make a skittering noise as it walks.  The pale color seems to be the result of living in dark, wet caves for its entire life.</pre>"
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
