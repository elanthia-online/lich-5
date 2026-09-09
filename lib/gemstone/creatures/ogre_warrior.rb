{
  schema_version: 3,
  name: "ogre warrior",
  noun: "warrior",
  url: "https://gswiki.play.net/ogre_warrior",
  picture: "",
  level: 20,
  family: "Ogre",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 250,
  speed: 10,
  height: 10,
  size: "large",
  areas: [
    {
      name: "Neartofar Forest",
      uids: [14015201..14015212]
    },
    {
      name: "Northern Slopes of Wehntoph",
      uids: [4302020..4302035]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Mace",
        as: (173..201)
      },
      {
        name: "Military pick",
        as: (177..193)
      },
      {
        name: "Broad-bladed steel hatchet",
        as: 169
      },
      {
        name: "Unknown",
        as: 173
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Sunder Shield"
      },
      {
        name: "Pounce"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (90..211),
    ranged: (90..129),
    bolt: (90..129),
    udf: (171..232),
    bar_td: 60,
    cle_td: (60..66),
    emp_td: (57..64),
    pal_td: (54..60),
    ran_td: (57..63),
    sor_td: (57..66),
    wiz_td: nil,
    mje_td: (60..66),
    mne_td: (60..66),
    mjs_td: (60..66),
    mns_td: (60..66),
    mnm_td: (57..66),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a broad-bladed steel hatchet",
    "a slatted reinforced wooden shield",
    "a black steel shield",
    "a red-trimmed black wool cape",
    "an iron studded mace",
    "some oiled red cuirboulli leather",
    "some steel-toed black leather boots"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an ogre tooth",
    other: "Glimmering blue essence shard",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The ogre warrior's bulging muscles and long arms give it an advantage in any encounter it might have. The heavy, rock hard skin serves equally well as armor or to just keep itself dry from the elements. Dark, smoking eyes glare out as it challenges any to oppose it."
    ],
    arrival: [
      "An ogre warrior just arrived."
    ],
    flee: [
      "An ogre warrior runs {direction}.",
      "An ogre warrior limps {direction}."
    ],
    death: [
      "The ogre warrior falls to the ground and dies.",
      "The ogre warrior screams one last time and dies.",
      "The ogre warrior falls to the floor and dies.",
      "The ogre warrior screams silently one last time and dies."
    ],
    decay: [
      "An ogre warrior decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "An ogre warrior swings {weapon} at you!",
        "An ogre warrior spits on the ground defiantly!",
        "An ogre warrior swings a broad-bladed steel hatchet at {target}!"
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
