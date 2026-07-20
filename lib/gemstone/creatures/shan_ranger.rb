{
  schema_version: 3,
  name: "shan ranger",
  noun: "",
  url: "https://gswiki.play.net/shan_ranger",
  picture: "",
  level: 42,
  family: "Shan",
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
      name: "Foggy Valley",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Longsword",
        as: 294
      }
    ],
    bolt_spells: [
      {
        name: "Web (118)",
        as: 276
      }
    ],
    warding_spells: [
      {
        name: "Wild Entropy (603)",
        cs: 188
      },
      {
        name: "Web (118)",
        cs: 194
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
      },
      {
        name: "Tangleweed (610)"
      },
      {
        name: "Sounds (607)"
      },
      {
        name: "Call Swarm (615)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "11",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 135,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: (135..138),
    sor_td: 160,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 165,
    mjs_td: nil,
    mns_td: 146,
    mnm_td: nil,
    defensive_spells: [
      "Mobility (618)",
      "Natural Colors (601)",
      "Self Control (613)",
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)"
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
    other: "Tiny golden seed"
  },
  messaging: {
    description: [
      "The shan ranger stands in a half-crouch, his long, knotty legs giving him that lanky, dangerous look of a wolf. Walking upright, the body covered with mottled grey fur and his long arms conclude in large, clawed hands with semi-opposable thumbs. The shan ranger's dog-like visage is fierce, with slavering jaws and eyes that glow like something out of a bad dream."
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
