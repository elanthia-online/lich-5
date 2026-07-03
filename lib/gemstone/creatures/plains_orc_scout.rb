{
  schema_version: 3,
  name: "plains orc scout",
  noun: "",
  url: "https://gswiki.play.net/plains_orc_scout",
  picture: "",
  level: 17,
  family: "Orc",
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
  max_hp: 150,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Orcswold",
      rooms: []
    },
    {
      name: "Yegharren Plains",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Longsword",
        as: 175
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Tangleweed (610)"
      }
    ],
    maneuvers: [],
    special_abilities: [
      {
        name: "Throw"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: (133..181),
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: (51..57),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: 57,
    mje_td: 57,
    mne_td: (51..57),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Natural Colors (601)",
      "Self Control (613)"
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
    skin: "scraggly orc scalp",
    other: nil
  },
  messaging: {
    description: [
      "As tall as a giantman and twice as muscular as most, the plains orc scout is taller and more agile than her more primitive orcish brothers, and judging by the cleverness in her beady yellow eyes, probably quite a bit more intelligent as well. Leathery brown skin covers her bulging limbs, the same color as the crude armor that protects her massive torso, and a scraggly red beard frames her heavy jowls."
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
