{
  schema_version: 3,
  name: "snow spectre",
  noun: "",
  url: "https://gswiki.play.net/snow_spectre",
  picture: "",
  level: 9,
  family: "Ghost",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Non-corporeal undead",
    "Element-based"
  ],
  bcs: nil,
  max_hp: 90,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Snow Fort",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 98
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Fear",
        cs: (47..53)
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: 0,
    udf: 24,
    bar_td: 27,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 27,
    wiz_td: nil,
    mje_td: 27,
    mne_td: 27,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: 27,
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
    skin: "a spectre nail",
    other: nil
  },
  messaging: {
    description: [
      "The snow spectre floats easily over the ground, seeming to move through solid obstacles with little effort. Its appearance alternates between a flickering, semi-transparent apparition and a near-blinding, white, icy solidity. Its face is permanently twisted into a tortured, leering grin and its eyes stare far ahead, as if transfixed on something horrible in the distance."
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
