{
  schema_version: 3,
  name: "shelfae chieftain",
  noun: "",
  url: "https://gswiki.play.net/shelfae_chieftain",
  picture: "",
  level: 11,
  family: "Shelfae",
  type: "Hybrid",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 140,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Coastal Cliffs",
      rooms: []
    },
    {
      name: "Marshtown",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Halberd",
        as: 130
      },
      {
        name: "Morning star",
        as: 130
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Tail strike"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "11",
    immunities: [],
    melee: (36..54),
    ranged: 6,
    bolt: nil,
    udf: nil,
    bar_td: 33,
    cle_td: nil,
    emp_td: 33,
    pal_td: nil,
    ran_td: nil,
    sor_td: 33,
    wiz_td: nil,
    mje_td: 33,
    mne_td: 33,
    mjs_td: 33,
    mns_td: 33,
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
    skin: "a shelfae crest",
    other: "No"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Similar to the shelfae soldier but taller by nearly two feet, the shelfae chieftain guides the legions of shelfae in combat.  Its taller stature, significantly brighter orange coloration, and protruding crest mark it as an officer.  Although formidably armed, the shelfae chieftain prefers to bring its opponents down first by sweeping its tail to produce a quake effect.</pre>"
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
