{
  schema_version: 3,
  name: "thyril",
  noun: "",
  url: "https://gswiki.play.net/thyril",
  picture: "",
  level: 2,
  family: "Thyril",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 51,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Wehnimer's Landing",
      rooms: []
    },
    {
      name: "Icemule Environs",
      rooms: []
    },
    {
      name: "Rambling Meadows",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 42
      },
      {
        name: "Scimitar",
        as: 52
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
    melee: (11..16),
    ranged: 1,
    bolt: 1,
    udf: 44,
    bar_td: 6,
    cle_td: nil,
    emp_td: 6,
    pal_td: 6,
    ran_td: 6,
    sor_td: 6,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 6,
    mjs_td: 6,
    mns_td: 6,
    mnm_td: 6,
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
    skin: "No",
    other: "Alchemy (common)"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>This soldier of the small mammal legions resembles an overgrown mole, except that it stands upright.  Intelligence is apparent in its bulbous, yellow eyes, and its clawed feet give it exceptional agility in moist areas.  The skin of the thyril is a muddy, mottled mass of light brown and dark brown hair, allowing it to blend in well with the decayed vegetation and soil in underground lairs and other dank locales.</pre>"
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
