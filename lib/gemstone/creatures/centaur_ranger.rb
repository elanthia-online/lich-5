{
  schema_version: 3,
  name: "centaur ranger",
  noun: "",
  url: "https://gswiki.play.net/centaur_ranger",
  picture: "",
  level: 25,
  family: "Centaur",
  type: "Hybrid",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: 7,
  size: "large",
  areas: [
    {
      name: "Rambling Meadows",
      uids: [14006041..14006046, 14006048..14006060]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Long bow",
        as: 208
      },
      {
        name: "Plain wooden arrow",
        as: 209
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
    ranged: (102..126),
    bolt: (102..122),
    udf: 139,
    bar_td: (66..75),
    cle_td: (70..79),
    emp_td: (75..81),
    pal_td: (65..74),
    ran_td: (65..71),
    sor_td: 78,
    wiz_td: nil,
    mje_td: (82..85),
    mne_td: (82..85),
    mjs_td: nil,
    mns_td: 72,
    mnm_td: (80..86),
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
  equipment: [
    "a wooden long bow",
    "some chain mail"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a centaur ranger hide",
    other: "Glimmering blue essence shardGlimmering blue mote of essence",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Seeming to be a blend of mannish torso upon the body of a light horse, the ranger has a certain charm and aura of mystery. That is, until you encounter one, for the ranger is a savage and wilder cousin to the great centaurs of legend and will lash out in terrible fury when it deems a threat is at hand. Its hide is valued for its toughness and durability and thus, many will brave the danger of flying hooves and the threat held by these fierce creatures to gain this prize."
    ],
    arrival: [],
    flee: [
      "A black centaur ranger gallops {direction}.",
      "A roan centaur ranger gallops {direction}.",
      "A bay centaur ranger gallops {direction}.",
      "A tan centaur ranger gallops {direction}.",
      "A white centaur ranger gallops {direction}."
    ],
    death: [
      "The tan centaur ranger screams one last time and dies.",
      "The black centaur ranger screams one last time and dies.",
      "The roan centaur ranger screams one last time and dies.",
      "The bay centaur ranger screams one last time and dies.",
      "The white centaur ranger screams one last time and dies.",
      "The black centaur ranger falls to the ground and dies.",
      "The tan centaur ranger falls to the ground and dies.",
      "The bay centaur ranger falls to the ground and dies.",
      "The white centaur ranger falls to the ground and dies.",
      "The roan centaur ranger falls to the ground and dies."
    ],
    decay: [
      "A roan centaur ranger dissolves into a puff of red smoke.",
      "A bay centaur ranger dissolves into a puff of red smoke.",
      "A white centaur ranger dissolves into a puff of red smoke.",
      "A tan centaur ranger dissolves into a puff of red smoke.",
      "A black centaur ranger dissolves into a puff of red smoke."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      fire: [
        "A centaur ranger fires {weapon} at you!"
      ]
    },
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
