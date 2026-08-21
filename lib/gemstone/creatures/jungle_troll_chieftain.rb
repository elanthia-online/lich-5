{
  schema_version: 3,
  name: "jungle troll chieftain",
  noun: "",
  url: "https://gswiki.play.net/jungle_troll_chieftain",
  picture: "",
  level: 30,
  family: "Troll",
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
  max_hp: 350,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Greymist Wood",
      rooms: []
    },
    {
      name: "Karazja Jungle",
      rooms: []
    }
  ],
  spawns: [
    { zone: 3021, count: 1, uid_ranges: [[3021001, 3021016]] },
    { zone: 3022, count: 2, uid_ranges: [[3022001, 3022034]] },
    { zone: 5006, count: 2, uid_ranges: [[5006001, 5006040]] }
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
    melee: 109,
    ranged: 86,
    bolt: 102,
    udf: 236,
    bar_td: 89,
    cle_td: nil,
    emp_td: 108,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: (109..114),
    mne_td: 98,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
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
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a scrap of troll skin",
    other: "a glimmering blue essence shard"
  },
  messaging: {
    description: [
      "A thin, tall creature, the troll chieftain scampers over the terrain in quick bursts. The a jungle troll chieftain's dark green, mottled skin displays an oily sheen, and hair is nowhere to be found on its body. An elongated face, perhaps two feet from the end of the exaggerated chin to the tips of the pointed ears, sits atop a thin, rubbery neck. Deep orange, slitted pupils nest horizontally in the steel grey eyes, and clusters of sharp orange horns poke up from the troll chieftain's head to surround the extended ears."
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
