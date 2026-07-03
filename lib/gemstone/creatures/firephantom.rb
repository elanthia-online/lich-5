{
  schema_version: 3,
  name: "firephantom",
  noun: "",
  url: "https://gswiki.play.net/firephantom",
  picture: "",
  level: 6,
  family: "Elemental",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Non-corporeal undead",
    "Element-based"
  ],
  bcs: nil,
  max_hp: 70,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Glatoph",
      rooms: []
    },
    {
      name: "Vornavian Coast",
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
        as: 77
      }
    ],
    bolt_spells: [
      {
        name: "Minor Fire (906)",
        as: 69
      },
      {
        name: "Major Fire (908)",
        as: 69
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: "-64",
    ranged: nil,
    bolt: "-61",
    udf: nil,
    bar_td: 18,
    cle_td: 18,
    emp_td: 18,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 18,
    mne_td: 18,
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
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>A billowing pillar of searing fire, the firephantom darts about quickly to set aflame any that would stand in its way.  Although it has a vaguely humanoid appearance, its form is entirely composed of fire, with the legs a dark red.  The darker red slowly gives way to blazing red in the torso and bright yellow in the cranial area.  Where the eyes and mouth should be only empty holes exist, floating eerily in the head of this mobile conflagration.</pre>"
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
