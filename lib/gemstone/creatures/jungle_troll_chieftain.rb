{
  schema_version: 3,
  name: "jungle troll chieftain",
  noun: "chieftain",
  url: "https://gswiki.play.net/jungle_troll_chieftain",
  picture: "",
  level: 30,
  family: "Troll",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 350,
  speed: 7,
  height: 10,
  size: "large",
  areas: [
    {
      name: "Karazja Jungle",
      uids: [5006001..5006009, 5006040..5006040]
    },
    {
      name: "Greymist Woods",
      uids: [3021001..3021016, 3022001..3022034]
    },
    {
      name: "unmapped",
      uids: [5006010..5006039]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bastard sword",
        as: 212
      },
      {
        name: "Claw (attack)",
        as: 227
      },
      {
        name: "Vine-wrapped rusting bastard sword",
        as: 272
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Call Swarm (615)"
      },
      {
        name: "Tangleweed (610)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (102..122),
    ranged: (82..127),
    bolt: (82..127),
    udf: (226..236),
    bar_td: 89,
    cle_td: (96..106),
    emp_td: (98..108),
    pal_td: (84..87),
    ran_td: (87..97),
    sor_td: (105..112),
    wiz_td: nil,
    mje_td: (98..114),
    mne_td: (98..114),
    mjs_td: (98..99),
    mns_td: (98..99),
    mnm_td: (100..105),
    defensive_spells: [
      "Natural Colors (601)",
      "Self Control (613)",
      "Mobility (618)",
      "Spirit Warding I (101)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a vine-wrapped rusting bastard sword"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a scrap of troll skin",
    other: "a glimmering blue essence shard",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A thin, tall creature, the troll chieftain scampers over the terrain in quick bursts. The a jungle troll chieftain's dark green, mottled skin displays an oily sheen, and hair is nowhere to be found on its body. An elongated face, perhaps two feet from the end of the exaggerated chin to the tips of the pointed ears, sits atop a thin, rubbery neck. Deep orange, slitted pupils nest horizontally in the steel grey eyes, and clusters of sharp orange horns poke up from the troll chieftain's head to surround the extended ears."
    ],
    arrival: [
      "A jungle troll chieftain just arrived!",
      "A jungle troll chieftain crashes into view!"
    ],
    flee: [],
    death: [
      "The troll chieftain snarls {pronoun} defiance before collapsing and going still.",
      "The troll chieftain snarls {pronoun} defiance one last time before going still."
    ],
    decay: [
      "A jungle troll chieftain decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A jungle troll chieftain swings {weapon} at you!",
        "A jungle troll chieftain swings a vine-wrapped rusting bastard sword at {target}!",
        "A jungle troll chieftain grunts, pointing at you!"
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
