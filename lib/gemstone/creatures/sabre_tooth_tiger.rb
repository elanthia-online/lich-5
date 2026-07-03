{
  schema_version: 3,
  name: "sabre-tooth tiger",
  noun: "",
  url: "https://gswiki.play.net/sabre-tooth_tiger",
  picture: "",
  level: 53,
  family: "Feline",
  type: "Quadruped",
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
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Arctic Tundra",
      rooms: []
    },
    {
      name: "Mount Aenatumgana",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 305
      },
      {
        name: "Charge",
        as: 315
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
    melee: 220,
    ranged: nil,
    bolt: (225..243),
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: 186,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: 186,
    mnm_td: (150..159),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a tiger incisor",
    other: nil
  },
  messaging: {
    description: [
      "The huge sabre-tooth tiger is obviously a formidable predator, measuring more than 15 feet from the nose to the tip of her tail. Flexing massive shoulders above powerful forelegs, the tiger growls and snarls, exposing the elongated canines that give her her name. The tiger's magnificent striped pelt gradates from a soft tan undertone along the spine to a powder white on belly and legs."
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
