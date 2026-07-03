{
  schema_version: 3,
  name: "necrotic snake",
  noun: "",
  url: "https://gswiki.play.net/necrotic_snake",
  picture: "",
  level: 48,
  family: "Reptilian",
  type: "Ophidian",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 260,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Marsh Keep",
      rooms: []
    },
    {
      name: "Fethayl Bog",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Strike",
        as: (277..291)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Constriction"
      },
      {
        name: "Poison Spit"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (255..426),
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 161,
    cle_td: 176,
    emp_td: 182,
    pal_td: nil,
    ran_td: 119,
    sor_td: (176..194),
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
    gems: false,
    boxes: false,
    skin: "a snake fang",
    other: nil
  },
  messaging: {
    description: [
      "The fearsome product of magical experimentation, the necrotic snake is larger than most men. Rotting scales cover the length of the undead reptile in a diamond pattern formed of various hues of brown, gold, and black. Large gashes in the snake's side reveal thin rib bones and the carcasses of previous meals, while leaking rancid fumes into the surrounding air."
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
