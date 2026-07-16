{
  schema_version: 3,
  name: "spiked cavern urchin",
  noun: "",
  url: "https://gswiki.play.net/spiked_cavern_urchin",
  picture: "",
  level: 17,
  family: "Urchin",
  type: "Globoid",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 160,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Thurfel's Keep",
      rooms: []
    },
    {
      name: "Hornwort Cavern",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pincer (attack)",
        as: "(barbed spines) 176"
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Barbed spines"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: 92,
    ranged: nil,
    bolt: nil,
    udf: 125,
    bar_td: 51,
    cle_td: 51,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 54,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 51,
    mjs_td: nil,
    mns_td: 51,
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
    skin: "a long fiery red spine",
    other: nil
  },
  messaging: {
    description: [
      "Long barbed spines erupt outward from the cavern urchin, almost completely covering its body. The spear-like growths form a formidable defense, and also pose a lethal threat to anything that might find itself close enough to become impaled upon the spiked ends."
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
