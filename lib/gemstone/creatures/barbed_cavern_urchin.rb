{
  schema_version: 3,
  name: "barbed cavern urchin",
  noun: "urchin",
  url: "https://gswiki.play.net/barbed_cavern_urchin",
  picture: "",
  level: 17,
  family: "Urchin",
  type: "Globoid",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 154,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Kraken's Fall",
      rooms: []
    }
  ],
  spawns: [
    { zone: 7131, count: 1, uid_ranges: [[7131001, 7131018]] }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Barbed spines",
        as: 176
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
    melee: (83..104),
    ranged: (68..80),
    bolt: (68..80),
    udf: 152,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 57,
    mne_td: nil,
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
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: nil,
    other: nil
  },
  messaging: {
    description: [],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    info: {
      general: [
        "Sibling of the spiked cavern urchin (also level 17, different zone)."
      ],
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
