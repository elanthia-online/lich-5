{
  schema_version: 3,
  name: "krolvin slaver",
  noun: "",
  url: "https://gswiki.play.net/krolvin_slaver",
  picture: "",
  level: 36,
  family: "Krolvin",
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
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Krolvin Carrack",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Scimitar",
        as: 230
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Bind (214)"
      },
      {
        name: "Silence (210)"
      }
    ],
    offensive_spells: [
      {
        name: "Major Elemental Wave (435)"
      },
      {
        name: "Tremors (909)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: (185..225),
    bar_td: (99..117),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: (99..117),
    wiz_td: nil,
    mje_td: nil,
    mne_td: (104..122),
    mjs_td: nil,
    mns_td: (99..117),
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
      "Although taller than the average krolvin, the slaver retains the characteristic long-fingered hands. His sturdy musculature is apparent beneath the grey-blue skin. Thick, coarse, white hair covers his head and spreads across his shoulders and down his back."
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
