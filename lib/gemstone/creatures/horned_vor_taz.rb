{
  schema_version: 3,
  name: "horned vor'taz",
  noun: "vor'taz",
  url: "https://gswiki.play.net/horned_vor'taz",
  picture: "",
  level: 48,
  family: "Vor'taz",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Magical"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: 7,
  size: "large",
  areas: [
    {
      name: "Gyldemar Forest",
      uids: [13030001..13030040]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge",
        as: (290..296)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Sun Burst (609)",
        cs: 225
      }
    ],
    offensive_spells: [
      {
        name: "Call Swarm (615)"
      },
      {
        name: "Sounds (607)"
      },
      {
        name: "Spirit Strike (117)"
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
    melee: (196..309),
    ranged: (146..247),
    bolt: (146..247),
    udf: (287..428),
    bar_td: (160..183),
    cle_td: (174..199),
    emp_td: (182..192),
    pal_td: (156..166),
    ran_td: (156..166),
    sor_td: (194..202),
    wiz_td: nil,
    mje_td: (204..208),
    mne_td: (204..208),
    mjs_td: (182..192),
    mns_td: (182..192),
    mnm_td: (153..162),
    defensive_spells: [
      "Natural Colors (601)",
      "Phoen's Strength (606)",
      "Self Control (613)",
      "Spirit Defense (103)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)"
    ],
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
    skin: "a vor'taz horn, a shiny vor'taz horn",
    other: [
      "Glowing violet essence dust",
      "glowing violet essence shard",
      "tiny golden seed"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "His fanged mouth frothing and snapping at the air, the horned vor'taz glares about with hate-filled eyes. Greater than the size of a human, the frame of the vor'taz is covered in dull grey flesh which is spotted with wart-like bumps. Affixed to his heavily muscled neck, the bony skull of the vor'taz supports a cruel horn which slashes back and forth in a menacing fashion."
    ],
    arrival: [],
    flee: [],
    death: [
      "The horned vor'taz's horn dims as {pronoun} lifeforce fades away.",
      "The horned vor'taz's horn dims, and {pronoun} falls to the ground dead."
    ],
    decay: [
      "A horned vor'taz crumbles away to nothing."
    ],
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
