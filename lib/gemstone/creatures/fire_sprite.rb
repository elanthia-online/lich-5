{
  schema_version: 3,
  name: "fire sprite",
  noun: "",
  url: "https://gswiki.play.net/fire_sprite",
  picture: "",
  level: 64,
  family: "Fey",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living",
    "Element-based"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Glaes Caverns",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist"
      }
    ],
    bolt_spells: [
      {
        name: "Major Fire"
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Elemental Dispel"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (371..403),
    ranged: (271..298),
    bolt: 287,
    udf: 414,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 270,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 290,
    mjs_td: nil,
    mns_td: 256,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I",
      "Elemental Defense II",
      "Elemental Defense III",
      "Thurfel's Ward"
    ],
    defensive_abilities: [],
    special_defenses: [
      "Immune to [[Limb Disruption]]"
    ]
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
    other: "[[Glowing violet mote of essence]]"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>At first glance, the fire sprite looks like nothing more than a ball of whirling flame, spitting smoke and ricocheting about the rocks like a dervish.  Gradually, her form coalesces, extending elongated arms and fingers, and short gnarled legs from the sphere of fire.  The fire sprite's hideous features are pulled into a grimace of hate, and her eyes are like two glowing coals, which spout sparks as the creature wavers in and out of her tenuous configuration.</pre>"
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
