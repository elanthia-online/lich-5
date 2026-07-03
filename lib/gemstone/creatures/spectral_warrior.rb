{
  schema_version: 3,
  name: "spectral warrior",
  noun: "",
  url: "https://gswiki.play.net/spectral_warrior",
  picture: "",
  level: 34,
  family: "Ghost",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 300,
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
        name: "Claw",
        as: 230
      },
      {
        name: "Flail",
        as: 250
      },
      {
        name: "Broadsword",
        as: 250
      },
      {
        name: "Halberd",
        as: 250
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Disarm"
      }
    ],
    special_abilities: [
      {
        name: "[[Attack strength]] boost"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "various",
    immunities: [],
    melee: 161,
    ranged: nil,
    bolt: 169,
    udf: 191,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 102,
    wiz_td: nil,
    mje_td: (94..109),
    mne_td: (94..109),
    mjs_td: nil,
    mns_td: 102,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: [
      "Immune to [[Unbalance]]"
    ]
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
      "<pre{{log2|margin-right=26em}}>The spectral warrior shimmers for an instant, seemingly half real and half phantom, his semi-ethereal armor faintly gleaming as it moves.  A gaunt face stares out from beneath the ghostly helm, his eyes swirling pits of blackness that seek out living foes, hatefully wishing to resign others to his own horrible fate.</pre>"
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
