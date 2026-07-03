{
  schema_version: 3,
  name: "wood sprite",
  noun: "",
  url: "https://gswiki.play.net/wood_sprite",
  picture: "",
  level: 38,
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
      name: "Gyldemar Forest",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Jeddart-axe",
        as: (236..321)
      },
      {
        name: "Spear",
        as: 230
      },
      {
        name: "Quarterstaff",
        as: 250
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Call Swarm (615)"
      },
      {
        name: "Lullabye (1005)"
      },
      {
        name: "Sounds (607)"
      },
      {
        name: "Tangleweed (610)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "9N",
    immunities: [],
    melee: 151,
    ranged: 107,
    bolt: nil,
    udf: nil,
    bar_td: (119..124),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 148,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 157,
    mjs_td: nil,
    mns_td: 141,
    mnm_td: nil,
    defensive_spells: [
      "Natural Colors (601)",
      "Phoen's Strength (606)",
      "Resist Elements (602)",
      "Self Control (613)",
      "Spirit Defense (103)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)",
      "Lesser Shroud (120)"
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
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: nil,
    other: "[[Glowing violet essence shard]]<br>[[Pristine sprite's hair]]"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Appearing more like an animated stick figure than a fleshy humanoid, the slender brown form of the wood sprite stands just under three feet.  Her eyes, two sparkling almond-shapes in her wood-like visage, belie a fervent sort of insanity as a frantic, incomprehensible whispering issues from her small mouth.</pre>"
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
