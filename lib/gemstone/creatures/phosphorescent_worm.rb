{
  schema_version: 3,
  name: "phosphorescent worm",
  noun: "",
  url: "https://gswiki.play.net/phosphorescent_worm",
  picture: "",
  level: 16,
  family: "Worm",
  type: "Worm",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 150,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Thurfel's Keep",
      rooms: []
    },
    {
      name: "Hornwort Cavern",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge (attack)",
        as: 154
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: 84,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: (45..51),
    cle_td: nil,
    emp_td: nil,
    pal_td: 42,
    ran_td: nil,
    sor_td: (42..54),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 48,
    mjs_td: nil,
    mns_td: 48,
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
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a faintly glowing worm skin",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The beast before you bears similarities to an earthworm, except it is considerably larger.  The beast has a gaping maw filled with tiny sharp teeth.  The phosphorescent slime coating the worm serves to both protect the beast and perhaps distract its foes.</pre>"
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
