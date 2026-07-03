{
  schema_version: 3,
  name: "siren lizard",
  noun: "",
  url: "https://gswiki.play.net/siren_lizard",
  picture: "",
  level: 42,
  family: "Reptilian",
  type: "Quadruped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Fhorian Village",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "claw (attack)",
        as: 267
      },
      {
        name: "Pound (attack)",
        as: 267
      },
      {
        name: "Ensnare (attack)",
        as: 277
      },
      {
        name: "Tail (attack)",
        as: 255
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Poison",
        cs: 126
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Tail lash"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: 164,
    ranged: nil,
    bolt: 173,
    udf: 248,
    bar_td: 137,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 159,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 167,
    mjs_td: nil,
    mns_td: 150,
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
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: "a multicolored siren lizard skin",
    other: nil
  },
  messaging: {
    description: [
      "The siren lizard has multicolored pastel skin which appears to be rather scaly, a long, blunt snout, sharp teeth, and a swiftly moving tail."
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
