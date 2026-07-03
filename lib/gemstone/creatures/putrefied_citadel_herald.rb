{
  schema_version: 3,
  name: "putrefied citadel herald",
  noun: "",
  url: "https://gswiki.play.net/putrefied_citadel_herald",
  picture: "",
  level: 60,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "corporeal undead"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Citadel",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Runestaff",
        as: 302
      }
    ],
    bolt_spells: [
      {
        name: "Fire Spirit (111)",
        as: (298..318)
      },
      {
        name: "Web Bolt (118)",
        as: 290
      }
    ],
    warding_spells: [
      {
        name: "Bind (214)",
        cs: (273..279)
      },
      {
        name: "Interference (212)"
      },
      {
        name: "Searing Light (135)",
        cs: 270
      },
      {
        name: "Silence (210)",
        cs: 273
      },
      {
        name: "Unbalance (110)"
      },
      {
        name: "Wither (1115)",
        cs: 285
      },
      {
        name: "Divine Wrath (335)",
        cs: 273
      }
    ],
    offensive_spells: [
      {
        name: "Spirit Strike (117)"
      },
      {
        name: "Web (118)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "2",
    immunities: [],
    melee: 303,
    ranged: 279,
    bolt: 239,
    udf: nil,
    bar_td: 232,
    cle_td: nil,
    emp_td: nil,
    pal_td: 242,
    ran_td: nil,
    sor_td: 280,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 283,
    mjs_td: nil,
    mns_td: 276,
    mnm_td: nil,
    defensive_spells: [
      "Fasthr's Reward (115)",
      "Lesser Shroud (120)",
      "Prayer of Protection (303)",
      "Spirit Shield (202)"
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
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Maggots crawl and writhe in the eye sockets of a putrefied Citadel herald.  Replete in immaculate costume, the herald stands stiffly with an expression of disdain on her withered face of grey putrified skin.  A large signet ring graces one of her two large wrinkled hands patiently folded one over the other.  A polished, leather scroll case hangs at the herald's side, embossed with a large letter \"E.\"</pre>"
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
