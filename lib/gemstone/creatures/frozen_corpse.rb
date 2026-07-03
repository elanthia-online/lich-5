{
  schema_version: 3,
  name: "frozen corpse",
  noun: "",
  url: "https://gswiki.play.net/frozen_corpse",
  picture: "",
  level: 42,
  family: "Zombie",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Corporeal undead",
    "Boss"
  ],
  bcs: true,
  max_hp: nil,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Arctic Tundra",
      rooms: []
    },
    {
      name: "Nightmare Gorge",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ice Pick",
        as: 282
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
    asg: nil,
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: (218..244),
    udf: nil,
    bar_td: 123,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 151,
    wiz_td: nil,
    mje_td: 168,
    mne_td: 153,
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
    skin: "scalp",
    other: nil
  },
  messaging: {
    description: [
      "Unearthed from his place of resting by the avalanches, the frozen corpse stiffly roams the ice fields looking for rest again. Ranging from dwarf to giantman in size, the frozen corpse attacks ruthlessly any living thing in his path, perhaps blaming the living for his current predicament. His features are taut and drawn, but most of the flesh is still intact, preserved by the subzero cold. His movements are punctuated by the loud screeching of ice against ice in his joints and a continual crackling as his frozen appendages fracture."
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
