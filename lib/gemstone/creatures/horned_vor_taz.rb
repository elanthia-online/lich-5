{
  schema_version: 3,
  name: "horned vor'taz",
  noun: "",
  url: "https://gswiki.play.net/horned_vor'taz",
  picture: "",
  level: 48,
  family: "Vor'taz",
  type: "Biped",
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
      name: "Gyldemar Forest",
      rooms: []
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
    melee: nil,
    ranged: 165,
    bolt: 202,
    udf: nil,
    bar_td: (160..183),
    cle_td: (174..193),
    emp_td: (182..195),
    pal_td: nil,
    ran_td: 166,
    sor_td: 202,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 208,
    mjs_td: nil,
    mns_td: 192,
    mnm_td: nil,
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
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a vor'taz horn, a shiny vor'taz horn",
    other: "Glowing violet essence dust"
  },
  messaging: {
    description: [
      "His fanged mouth frothing and snapping at the air, the horned vor'taz glares about with hate-filled eyes. Greater than the size of a human, the frame of the vor'taz is covered in dull grey flesh which is spotted with wart-like bumps. Affixed to his heavily muscled neck, the bony skull of the vor'taz supports a cruel horn which slashes back and forth in a menacing fashion."
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
