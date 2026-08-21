{
  schema_version: 3,
  name: "wall guardian",
  noun: "",
  url: "https://gswiki.play.net/wall_guardian",
  picture: "",
  level: 11,
  family: "Humanoid",
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
  max_hp: 159,
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
    { zone: 7531, count: 2, uid_ranges: [[7531001, 7531042]] }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Military pick",
        as: (100..153)
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
    asg: "16",
    immunities: [],
    melee: (62..144),
    ranged: (61..76),
    bolt: (61..76),
    udf: 171,
    bar_td: 27,
    cle_td: 33,
    emp_td: 13,
    pal_td: nil,
    ran_td: nil,
    sor_td: 27,
    wiz_td: nil,
    mje_td: 33,
    mne_td: 33,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: 33,
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
      "The wall guardian is a bit taller than a halfling, but not by much. Filthy, stinky and smelly, she looks as if she hasn't bathed in years. A faint smirk is etched on the face of the guardian."
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
