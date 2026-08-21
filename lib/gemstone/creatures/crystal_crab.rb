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
  max_hp: 94,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Thurfel's Keep",
      rooms: []
    }
  ],
  spawns: [
    { zone: 7530, count: 1, uid_ranges: [[7530006, 7530029]] }
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
    melee: (38..81),
    ranged: (38..44),
    bolt: (38..44),
    udf: 99,
    bar_td: 24,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 24,
    wiz_td: nil,
    mje_td: 24,
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
