{
  schema_version: 3,
  name: "centaur ranger",
  noun: "",
  url: "https://gswiki.play.net/centaur_ranger",
  picture: "",
  level: 23,
  family: "Centaur",
  type: "Hybrid",
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
      name: "Rambling Meadows",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Long bow",
        as: 208
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Call Swarm (615)"
      },
      {
        name: "Sounds (607)"
      },
      {
        name: "Tangleweed (610)"
      }
    ],
    maneuvers: [
      {
        name: "Kick"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "13",
    immunities: [],
    melee: 108,
    ranged: (113..126),
    bolt: nil,
    udf: nil,
    bar_td: (66..75),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 78,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 82,
    mjs_td: nil,
    mns_td: 72,
    mnm_td: nil,
    defensive_spells: [
      "Natural Colors (601)",
      "Resist Elements (602)",
      "Self Control (613)",
      "Spirit Warding I (101)",
      "Spirit Defense (103)"
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
    skin: "a centaur ranger hide",
    other: "Glimmering blue essence shardGlimmering blue mote of essence"
  },
  messaging: {
    description: [
      "Seeming to be a blend of mannish torso upon the body of a light horse, the ranger has a certain charm and aura of mystery. That is, until you encounter one, for the ranger is a savage and wilder cousin to the great centaurs of legend and will lash out in terrible fury when it deems a threat is at hand. Its hide is valued for its toughness and durability and thus, many will brave the danger of flying hooves and the threat held by these fierce creatures to gain this prize."
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
