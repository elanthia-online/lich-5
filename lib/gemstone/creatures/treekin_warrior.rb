{
  schema_version: 3,
  name: "treekin warrior",
  noun: "",
  url: "https://gswiki.play.net/treekin_warrior",
  picture: "",
  level: 80,
  family: "Tree",
  type: "Plantlife",
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
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Red Forest",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound",
        as: 390
      },
      {
        name: "Root lash",
        as: 390
      },
      {
        name: "Root slam",
        as: 390
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Twin Hammerfists"
      },
      {
        name: "Caber toss"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "17",
    immunities: [
      "Stun"
    ],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 312,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 337,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
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
    skin: "blood-stained bark",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Standing approximately twelve feet tall, the treekin warrior towers menacingly before you.  Lambent yellow eyes and thick leg-shaped roots make it clear that this is no ordinary tree.  Leaves cover the warrior from head to trunk, with two arm-shaped branches protruding from the canopy.  Numerous gashes and chips indicate that this particular specimen has seen much combat in the past.</pre>"
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
