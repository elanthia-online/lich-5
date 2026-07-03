{
  schema_version: 3,
  name: "treekin druid",
  noun: "",
  url: "https://gswiki.play.net/treekin_druid",
  picture: "",
  level: 83,
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
        as: 400
      },
      {
        name: "Root lash",
        as: 400
      },
      {
        name: "Root slam",
        as: 400
      }
    ],
    bolt_spells: [
      {
        name: "Hurl Boulder (510)",
        as: 350
      }
    ],
    warding_spells: [
      {
        name: "Searing Light (135)",
        cs: 340
      }
    ],
    offensive_spells: [
      {
        name: "Call Swarm (615)"
      },
      {
        name: "Spirit Dispel (119)"
      },
      {
        name: "Spike Thorn (616)"
      },
      {
        name: "Phoen's Strength (606)"
      }
    ],
    maneuvers: [
      {
        name: "Whirlwind of leaves (or pollen)"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: 217,
    udf: nil,
    bar_td: 329,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: (365..379),
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Barkskin",
      "Natural Colors (601)",
      "Resist Elements (602)"
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
    skin: "mossy beard",
    other: nil
  },
  messaging: {
    description: [
      "Standing approximately eight feet tall, the treekin druid glares at you with malevolent intent. Lambent yellow eyes and thick leg-shaped roots make it clear that this is no ordinary tree. Leaves cover the druid from head to trunk, with two arm-shaped branches protruding from the canopy. A long mossy beard dangles below a crooked knothole under the eyes, giving gnarled look to an already imposing foe."
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
