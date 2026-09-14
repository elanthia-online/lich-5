{
  schema_version: 3,
  name: "niirsha",
  noun: "niirsha",
  url: "https://gswiki.play.net/niirsha",
  picture: "",
  level: 23,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 191,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Lunule Weald",
      uids: [14016001..14016038]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Goupillon",
        as: 164
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Bind (214)",
        cs: 133
      },
      {
        name: "Point",
        cs: 139
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [],
    melee: (131..185),
    ranged: (134..169),
    bolt: (134..173),
    udf: (155..222),
    bar_td: 90,
    cle_td: (80..90),
    emp_td: (79..89),
    pal_td: (66..76),
    ran_td: (66..76),
    sor_td: (77..90),
    wiz_td: nil,
    mje_td: (83..95),
    mne_td: (83..95),
    mjs_td: (92..100),
    mns_td: (92..100),
    mnm_td: (78..87),
    defensive_spells: [
      "Prayer of Protection",
      "Spirit Warding I",
      "Spirit Warding II"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a corroded iron goupillon"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Reticulated orbsGlimmering blue essence shard",
      "glimmering blue mote of essence"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The niirsha floats just above the ground, his appearance that of glorious beauty. However, as one approaches the niirsha, his majestic visage begins to crack and peel away to reveal the horrible face of an undead monster. Continually shedding and regenerating his flesh, the niirsha seems locked in a never-ending battle to recapture his former beauty. The niirsha violently preys upon all passers-by, hoping to replace his own cursed flesh with that of the living."
    ],
    arrival: [
      "A niirsha shambles in!"
    ],
    flee: [
      "A niirsha wails madly as he limps {direction}.",
      "A niirsha shambles {direction}."
    ],
    death: [
      "The niirsha falls to the ground motionless.",
      "The niirsha wails in terrifying pain one last time and lies still."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      cast: [
        "A niirsha points a rotting finger at you!"
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
