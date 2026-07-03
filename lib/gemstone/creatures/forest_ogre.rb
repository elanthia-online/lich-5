{
  schema_version: 3,
  name: "forest ogre",
  noun: "",
  url: "https://gswiki.play.net/forest_ogre",
  picture: "",
  level: 17,
  family: "Ogre",
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
  max_hp: 220,
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
        name: "Closed fist",
        as: 178
      },
      {
        name: "Falchion",
        as: 178
      },
      {
        name: "Pound",
        as: 178
      },
      {
        name: "Stomp",
        as: 178
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tackle"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "17",
    immunities: [],
    melee: (91..106),
    ranged: nil,
    bolt: 82,
    udf: nil,
    bar_td: (45..51),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 51,
    mne_td: 51,
    mjs_td: 51,
    mns_td: nil,
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
    skin: "an ogre tusk",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The forest ogre is similar to its troll cousins, being very large, very strong, and very stupid.  However, two differences are immediately noticeable.  The forest ogre moves nearly silently, not in the heavy, lumbering gait of its cousins, and it does not smell nearly as bad, perhaps due to its constant contact with the pine sap and needles of the forest conifers.  It is still just as dangerous.</pre>"
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
