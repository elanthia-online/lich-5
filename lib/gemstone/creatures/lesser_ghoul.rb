{
  schema_version: 3,
  name: "lesser ghoul",
  noun: "ghoul",
  url: "https://gswiki.play.net/lesser_ghoul",
  picture: "",
  level: 1,
  family: "Ghoul",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 40,
  speed: 15,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "Glaise Cnoc Cemetery",
      uids: [14008001..14008033, 14008060..14008070]
    },
    {
      name: "The Graveyard",
      uids: [18003..18011, 18013..18028, 2162201..2162211]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 31
      },
      {
        name: "Unknown",
        as: 31
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (-12..50),
    ranged: (-13..49),
    bolt: (-13..49),
    udf: 46,
    bar_td: 3,
    cle_td: 3,
    emp_td: 3,
    pal_td: (0..3),
    ran_td: 3,
    sor_td: 3,
    wiz_td: 3,
    mje_td: 3,
    mne_td: 3,
    mjs_td: (3..9),
    mns_td: (3..9),
    mnm_td: 3,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "ghoul nail",
      "ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Resembling a decaying corpse more than anything else, the lesser ghoul is hunched over so that its long arms trail along the ground. Sharp claw-like nails tip both hands and feet and the stench of corruption wafts thickly from the sodden rags of clothing that cling to its leprous body. Strings of gnawed flesh drop from the creature's loose-lipped mouth as it continues to chew on something better left unknown."
    ],
    arrival: [
      "A lesser ghoul just arrived!",
      "A lesser ghoul just arrived."
    ],
    flee: [],
    death: [
      "The lesser ghoul falls to the ground motionless.",
      "The lesser ghoul screams evilly one last time and goes still."
    ],
    decay: [
      "A lesser ghoul turns to dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      claw: [
        "A lesser ghoul claws at you!"
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
