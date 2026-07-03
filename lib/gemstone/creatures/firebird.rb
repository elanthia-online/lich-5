{
  schema_version: 3,
  name: "firebird",
  noun: "",
  url: "https://gswiki.play.net/firebird",
  picture: "",
  level: 85,
  family: "Bird",
  type: "Avian",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living",
    "Element-based",
    "Magical"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The F'Eyrie",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw (attack)",
        as: 385
      },
      {
        name: "Bite (attack)",
        as: 375
      },
      {
        name: "Impale (attack)",
        as: 380
      }
    ],
    bolt_spells: [
      {
        name: "Major Fire (908)",
        as: 302
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Wing Buffet"
      },
      {
        name: "Screech"
      },
      {
        name: "Fire Mote"
      },
      {
        name: "Drop"
      },
      {
        name: "Fire flares"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: 344,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 359,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: 333,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "Flying",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: nil,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: "a red firebird feather",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Smoldering black eyes and a sharp golden beak display the fury of the firebird.  A golden crest of feathers adorn the head of this large but nimble avian that continues down its long craning neck, transitioning to orange around its sleek body, then deep red along its narrow legs that end in wickedly sharp black talons.  Flames dance from the firebird's wide arcing wings that leave a trail with its long tail feathers in its wake.</pre>"
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
