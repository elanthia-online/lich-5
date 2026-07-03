{
  schema_version: 3,
  name: "arch wight",
  noun: "",
  url: "https://gswiki.play.net/arch_wight",
  picture: "",
  level: 20,
  family: "Wight",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 170,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Castle Anwyn",
      rooms: []
    },
    {
      name: "Plains of Bone",
      rooms: []
    },
    {
      name: "Temple of Hope",
      rooms: []
    },
    {
      name: "The Graveyard",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Scimitar",
        as: 156
      },
      {
        name: "Claw",
        as: 136
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Mind Jolt (706)",
        cs: 123
      },
      {
        name: "Empathy (1108)"
      }
    ],
    offensive_spells: [
      {
        name: "Earthen Fury (917)"
      },
      {
        name: "Gas cloud"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "10",
    immunities: [],
    melee: 113,
    ranged: nil,
    bolt: 55,
    udf: nil,
    bar_td: 66,
    cle_td: 60,
    emp_td: 60,
    pal_td: 60,
    ran_td: 60,
    sor_td: 60,
    wiz_td: 60,
    mje_td: 60,
    mne_td: 60,
    mjs_td: 60,
    mns_td: 60,
    mnm_td: 60,
    defensive_spells: [
      "Spirit Warding II (107)",
      "Spell Shield (219)"
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
    gems: nil,
    boxes: nil,
    skin: "a wight skin",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The arch wight moves along ponderously, its gaunt humanoid frame often bent nearly double as it walks through the corridors of the deceased.  Massive upper arms contrast with a thin torso and narrow hips.  Its liquid golden eyes seem to be filled with tiny red sparks, and the lack of flesh on its face causes the arch wight to sport a horrific toothy grin.  Very proficient in the ways of magic, the arch wight feasts upon the flesh of the deceased, but often cooks the living to death before indulging in its grisly meal.</pre>"
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
