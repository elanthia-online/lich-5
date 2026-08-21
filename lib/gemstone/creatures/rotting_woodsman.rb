{
  schema_version: 3,
  name: "rotting woodsman",
  noun: "",
  url: "https://gswiki.play.net/rotting_woodsman",
  picture: "",
  level: 23,
  family: "Humanoid",
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
  max_hp: 260,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Marshtown",
      rooms: []
    }
  ],
  spawns: [
    { zone: 4212, count: 1, uid_ranges: [[4212201, 4212222]] }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Battle axe",
        as: 202
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
    melee: (165..181),
    ranged: (115..169),
    bolt: (115..169),
    udf: 265,
    bar_td: 69,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 74,
    wiz_td: nil,
    mje_td: 79,
    mne_td: 77,
    mjs_td: nil,
    mns_td: 72,
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
      "The rotting woodsman staggers about through the forests she once knew in life, now unable to obtain rest. Putrid flesh drips from her exposed bones, and only ragged patches of hair remain on her thick skull. Despite the lack of solid muscle, the rotting woodsman swings her axe with enormous power, felling the living as she once felled the immense trees of the forest."
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
