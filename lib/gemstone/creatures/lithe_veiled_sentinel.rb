{
  schema_version: 3,
  name: "lithe veiled sentinel",
  noun: "",
  url: "https://gswiki.play.net/lithe_veiled_sentinel",
  picture: "",
  level: 96,
  family: "Humanoid",
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
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Sanctum",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Kick",
        as: 458
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Thought Lash",
        cs: (438..447)
      }
    ],
    offensive_spells: [
      {
        name: "Spirit Strike"
      },
      {
        name: "Force Projection"
      },
      {
        name: "Powersink"
      }
    ],
    maneuvers: [
      {
        name: "Feint"
      },
      {
        name: "Bull Rush"
      }
    ],
    special_abilities: [
      {
        name: "[[Unholy Quickening]]"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "20",
    immunities: [
      "Stun"
    ],
    melee: 338,
    ranged: (320..364),
    bolt: 331,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: 403,
    ran_td: 331,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Iron Skin",
      "Spirit Warding I",
      "Spirit Warding II",
      "Bravery",
      "Strength",
      "Foresight",
      "Mindward",
      "Focus Barrier"
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
      "<pre{{log2|margin-right=26em}}>Blessed with an improbably lithe physique and muscles like corded iron, a lithe veiled sentinel is a short female with a face deeply darkened and lined by the sun's ungentle kiss.  Her eyes are constantly, warily moving, and with every darting motion, they flash with a sharp-edged lambency like the glint of moonlight off of a shard of blue-green glass.  The woman wears her shirt open to the waist, but is swathed in a shroud of green silk that flows in a rippling current on the air behind her.  She is deadly grace embodied.</pre>"
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
