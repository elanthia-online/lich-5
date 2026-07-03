{
  schema_version: 3,
  name: "forest trali shaman",
  noun: "",
  url: "https://gswiki.play.net/forest_trali_shaman",
  picture: "",
  level: 46,
  family: "Trali",
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
      name: "Gyldemar Green",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Mace",
        as: 271
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Bind (214)",
        cs: 224
      },
      {
        name: "Calm (201)"
      },
      {
        name: "Silence (210)"
      },
      {
        name: "Unbalance (110)"
      }
    ],
    offensive_spells: [
      {
        name: "Phoen's Strength (606)"
      },
      {
        name: "Spirit Strike (117)"
      },
      {
        name: "Spike Thorn (616)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "9",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: (149..172),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 193,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 198,
    mjs_td: nil,
    mns_td: 183,
    mnm_td: nil,
    defensive_spells: [
      "Natural Colors (601)",
      "Spirit Defense (103)",
      "Spirit Shield (202)",
      "Spell Shield (219)",
      "Spirit Warding I (101)"
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
    skin: "a trali scalp",
    other: "[[Glowing violet essence dust]],"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Standing nearly six feet tall, the man-like trali shaman watches adventurers' every move with piercing grey eyes.  A short matted, reddish grey mane covers his head and his skin has a greenish grey hue.  There is little doubt that the stealthy trali shaman can be a formidable opponent when need arises, or when he is hard pressed.</pre>"
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
