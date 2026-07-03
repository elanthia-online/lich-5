{
  schema_version: 3,
  name: "fire cat",
  noun: "",
  url: "https://gswiki.play.net/fire_cat",
  picture: "",
  level: 18,
  family: "Feline",
  type: "Quadruped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living",
    "Magical",
    "Element-based"
  ],
  bcs: true,
  max_hp: 160,
  speed: "10 sec",
  height: nil,
  size: "",
  areas: [
    {
      name: "Smokey Caverns",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 164
      },
      {
        name: "Bite",
        as: 170
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "[[Pounce]]"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [
      "Fire"
    ],
    melee: "96 to 146",
    ranged: nil,
    bolt: "85 to 91",
    udf: 124,
    bar_td: 54,
    cle_td: 54,
    emp_td: 54,
    pal_td: 54,
    ran_td: 54,
    sor_td: (48..54),
    wiz_td: 54,
    mje_td: 54,
    mne_td: 54,
    mjs_td: 54,
    mns_td: 54,
    mnm_td: 54,
    defensive_spells: [],
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
    skin: "a fire cat claw",
    other: "[[essence of fire]]"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The fire cat is a sleek cat, a real beauty to behold.  It is fairly large, standing roughly head-high to a halfling.  Its fur ranges from red to orange in color and it has long claws that have a metallic glint.</pre>"
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
