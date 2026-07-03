{
  schema_version: 3,
  name: "ilvari pixie",
  noun: "",
  url: "https://gswiki.play.net/ilvari_pixie",
  picture: "",
  level: 74,
  family: "Fey",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living",
    "Magical"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Red Forest",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Giant bee stinger",
        as: (356..378)
      }
    ],
    bolt_spells: [
      {
        name: "Major Acid (1710)",
        as: 352
      }
    ],
    warding_spells: [
      {
        name: "Pain (711)",
        cs: 339
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Dispel (417)"
      },
      {
        name: "Major Elemental Wave (435)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "5N",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: (312..333),
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Arcane Barrier (1720)",
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Invisibility (916)"
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
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "This smallish humanoid sports a pair of expressive sparkling eyes, lightly tanned skin, and a wide grin from ear to ear. Cute is too kind of a word for this caricature of elven descent. A faintly shimmering golden aura surrounds him."
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
