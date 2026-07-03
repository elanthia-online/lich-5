{
  schema_version: 3,
  name: "ilvari sprite",
  noun: "",
  url: "https://gswiki.play.net/ilvari_sprite",
  picture: "",
  level: 73,
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
    physical_attacks: [],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Bone Shatter (1106)",
        cs: (306..315)
      },
      {
        name: "Repel (Fear)",
        cs: (306..315)
      },
      {
        name: "Wither (1115)",
        cs: (306..315)
      },
      {
        name: "Sympathy (1120)"
      }
    ],
    offensive_spells: [
      {
        name: "Spirit Dispel (119)"
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
    ranged: 360,
    bolt: 340,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: (300..315),
    wiz_td: nil,
    mje_td: 328,
    mne_td: (326..338),
    mjs_td: nil,
    mns_td: 306,
    mnm_td: nil,
    defensive_spells: [
      "Lesser Shroud (120)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)",
      "Wall of Force (140)"
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
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>\nThe subtle hourglass figure of this tiny offshoot of an elven female is all you can see due to a strange silvery aura covering her.  Her face is the exception, for it shows through as a near picture perfect model of beauty.  The only spoiler in the package is the strange look of madness in her shimmering silver eyes.\n</pre>"
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
