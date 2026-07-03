{
  schema_version: 3,
  name: "crystal crab",
  noun: "",
  url: "https://gswiki.play.net/crystal_crab",
  picture: "",
  level: 8,
  family: "Crab",
  type: "Crustacean",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 85,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Thurfel's Keep",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ensnare",
        as: 122
      },
      {
        name: "Claw",
        as: 112
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
    asg: "9N",
    immunities: [],
    melee: (21..81),
    ranged: nil,
    bolt: 44,
    udf: (41..99),
    bar_td: 24,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 24,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 24,
    mjs_td: nil,
    mns_td: 24,
    mnm_td: 24,
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
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: "a faceted crystal crab shell",
    other: nil
  },
  messaging: {
    description: [
      "The multi-faceted shell of this oversized crab resembles a massive oval gem. Underneath the protective covering are its formidable claws and pincers, the front pair easily the largest. The creature's eyestalks peer about nervously at even the slightest sound."
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
