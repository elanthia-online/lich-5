{
  schema_version: 3,
  name: "snow crone",
  noun: "",
  url: "https://gswiki.play.net/snow_crone",
  picture: "",
  level: 36,
  family: "Witch",
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
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Glatoph",
      rooms: []
    },
    {
      name: "Northern Mountains",
      rooms: []
    },
    {
      name: "Olbin Pass",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [],
    bolt_spells: [
      {
        name: "Major Cold (907)",
        as: 227
      }
    ],
    warding_spells: [
      {
        name: "Mana Disruption (702)",
        cs: 201
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Gas Cloud"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: 235,
    ranged: (190..199),
    bolt: 203,
    udf: nil,
    bar_td: (113..118),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 142,
    wiz_td: nil,
    mje_td: 139,
    mne_td: 143,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Defense (103)",
      "Spirit Warding I (101)"
    ],
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
    skin: "a crooked crone finger",
    other: nil
  },
  messaging: {
    description: [
      "Glistening in the light, the crone's snow white skin is covered with frost and snow.  Seemingly formed of living snow, the crone is a cold, imposing creature.  The snow crone has a mop of tangle ice blue hair sticking out wildly in all directions."
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
