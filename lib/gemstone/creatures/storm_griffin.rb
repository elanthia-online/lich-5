{
  schema_version: 3,
  name: "storm griffin",
  noun: "",
  url: "https://gswiki.play.net/storm_griffin",
  picture: "",
  level: 73,
  family: "Griffin",
  type: "Hybrid",
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
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Griffin's Keen",
      rooms: []
    },
    {
      name: "Stormpeak",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 368
      },
      {
        name: "Impale",
        as: 358
      },
      {
        name: "Bite",
        as: 358
      }
    ],
    bolt_spells: [
      {
        name: "Major Shock (910)",
        as: 321
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Call Wind (912)"
      },
      {
        name: "Lightning mote"
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
    melee: 264,
    ranged: nil,
    bolt: 263,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 306,
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
    magic_items: nil,
    gems: true,
    boxes: false,
    skin: "soft blue griffin feather",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The storm griffin is a magnificent beast, as if designed by the gods to embody fierce and graceful predation.  Its front legs, forebody, wings, and head are those of a great eagle, complete with large powder-blue feathers and aquiline beak.  The rear half of the creature's body is that of a powerful lion, with short, sandy blonde fur and a long feline tail.  A tendril of electricity snakes across one outstreched claw as the storm griffin glares about with its piercing blue eyes.</pre>"
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
