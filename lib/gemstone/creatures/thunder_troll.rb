{
  schema_version: 3,
  name: "thunder troll",
  noun: "",
  url: "https://gswiki.play.net/thunder_troll",
  picture: "",
  level: 18,
  family: "Troll",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living",
    "Element-based"
  ],
  bcs: true,
  max_hp: 160,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Foggy Valley",
      rooms: []
    },
    {
      name: "Wehntoph",
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
        name: "War mattock",
        as: 163
      }
    ],
    bolt_spells: [
      {
        name: "Major Shock (910)",
        as: 117
      }
    ],
    warding_spells: [
      {
        name: "Pain (711)",
        cs: 98
      }
    ],
    offensive_spells: [
      {
        name: "Call Wind (912)"
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
    asg: "10N",
    immunities: [],
    melee: 102,
    ranged: nil,
    bolt: (91..116),
    udf: nil,
    bar_td: (41..68),
    cle_td: nil,
    emp_td: nil,
    pal_td: 49,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 53,
    mne_td: 53,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I",
      "Elemental Defense II",
      "Spirit Defense",
      "Spirit Warding I",
      "Spirit Warding II"
    ],
    defensive_abilities: [],
    special_defenses: [
      "Shake off [[Stun|stuns]]"
    ]
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
    skin: "a troll scalp",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Tall but sleek, the size of the thunder troll belies its quickness.  The thunder troll moves about surrounded by a raging tempest.  An upturned lip, protruding jaw and sunken, orange eyes impart an air of arrogance to this foul, rubbery creature.  Given to sudden fits of uncontrollable rage, a thunder troll has been known to spring from the forest and tear a seasoned warrior in half before the warrior can even cry out, then, surprisingly, turn and dart away, distracted, leaving small children unharmed.</pre>"
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
