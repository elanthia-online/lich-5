{
  schema_version: 3,
  name: "grifflet",
  noun: "",
  url: "https://gswiki.play.net/grifflet",
  picture: "",
  level: 64,
  family: "Griffin",
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
  max_hp: 260,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Griffin's Keen",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Impale",
        as: 342
      },
      {
        name: "Bite",
        as: 342
      },
      {
        name: "Claw",
        as: 352
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Call Wind (912)"
      },
      {
        name: "Screech"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: 265,
    ranged: nil,
    bolt: 263,
    udf: nil,
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
    gems: true,
    boxes: false,
    skin: "a grifflet pelt",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The grifflet is a young, yet magnificent beast.  Mottled brown feathers marked with light splotches cover the grifflet's front legs, forebody, and wings, while the creature's eagle-like head is almost completely grey.  The rear half of the grifflet's body is that of a young lion, with short, pale yellow fur and a long feline tail.  Even at this immature stage of life, the horse-sized grifflet is a deadly foe.</pre>"
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
