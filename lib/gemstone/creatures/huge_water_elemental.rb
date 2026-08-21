{
  schema_version: 3,
  name: "huge water elemental",
  noun: "",
  url: "https://gswiki.play.net/huge_water_elemental",
  picture: "",
  level: 95,
  family: "Elemental",
  type: "Elemental",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Extraplanar",
    "Magical"
  ],
  bcs: true,
  max_hp: nil,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Elemental Confluence",
      rooms: []
    }
  ],
  spawns: [
    { zone: 580, count: 1, uid_ranges: [[580001, 580025]] },
    { zone: 581, count: 1, uid_ranges: [[581001, 581025]] },
    { zone: 582, count: 1, uid_ranges: [[582001, 582025]] },
    { zone: 583, count: 1, uid_ranges: [[583001, 583025]] },
    { zone: 584, count: 1, uid_ranges: [[584001, 584025]] },
    { zone: 585, count: 1, uid_ranges: [[585001, 585025]] },
    { zone: 586, count: 1, uid_ranges: [[586001, 586025]] },
    { zone: 587, count: 1, uid_ranges: [[587001, 587025]] },
    { zone: 588, count: 1, uid_ranges: [[588001, 588025]] }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound",
        as: 450
      }
    ],
    bolt_spells: [
      {
        name: "Minor Water (903)",
        as: 452
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Mystic Impedance (1708)"
      }
    ],
    maneuvers: [
      {
        name: "Water blast"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "10",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: 356,
    udf: nil,
    bar_td: 370,
    cle_td: 400,
    emp_td: 400,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 400,
    mns_td: 400,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Barrier",
      "Elemental Bias",
      "Elemental Defense I",
      "Elemental Defense II",
      "Elemental Defense III",
      "Elemental Targeting"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: nil,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: nil,
    other: "essence of water"
  },
  messaging: {
    description: [
      "The water elemental's upper body is that of a humanoid, while its lower body forms a turbulent, watery vortex. The facial features of the elemental creature are vague and shifting, rippling with every contortion of its face. Sloshing and splashing noises accompany each movement of the water elemental, along with an odd gurgling."
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
