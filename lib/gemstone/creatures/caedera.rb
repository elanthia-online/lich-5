{
  schema_version: 3,
  name: "caedera",
  noun: "",
  url: "https://gswiki.play.net/caedera",
  picture: "",
  level: 82,
  family: "Worm",
  type: "Worm",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living",
    "Magical"
  ],
  bcs: true,
  max_hp: 600,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Rift",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (420..440)
      },
      {
        name: "Charge (attack)",
        as: (420..440)
      },
      {
        name: "Ensnare (attack)",
        as: (420..440)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Burrow"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: nil,
    ranged: "+321",
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: (326..338),
    wiz_td: nil,
    mje_td: 345,
    mne_td: nil,
    mjs_td: nil,
    mns_td: 308,
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
    gems: false,
    boxes: false,
    skin: "a caedera skin",
    other: "No"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The caedera looms malevolently over its prey.  Yellow ichor drips from its slavering jaws as its massive head lolls blindly from side to side.  Keen senses of smell and sound lead this gargantuan worm to the location of its next meal.  Its segmented body contracts and expands powerfully, allowing the beast to burrow through rock and soil with the same ease that other creatures move through the air.  Each segment is dark orange with mottled brown spots, though the rings where the segments join are a charcoal grey.</pre>"
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
