{
  schema_version: 3,
  name: "fire ogre",
  noun: "",
  url: "https://gswiki.play.net/fire_ogre",
  picture: "",
  level: 28,
  family: "Ogre",
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
  max_hp: 225,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Greymist Wood",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Flail",
        as: 245
      }
    ],
    bolt_spells: [
      {
        name: "Major Fire (908)",
        as: 167
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "17N",
    immunities: [],
    melee: nil,
    ranged: (92..123),
    bolt: nil,
    udf: nil,
    bar_td: (101..115),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 104,
    wiz_td: nil,
    mje_td: 113,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I",
      "Elemental Defense II"
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
    skin: "ogre tooth",
    other: "shimmering blue essence shard<br>essence of fire"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Easily three times as large as the largest giantman, this brutish creature glares about with fire red eyes.  The fire ogre has black, soot-covered skin and fiery orange hair.  Steam pours from her nose as she flexes her massive claws.</pre>"
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
