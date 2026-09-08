{
  schema_version: 3,
  name: "plains orc warrior",
  noun: "warrior",
  url: "https://gswiki.play.net/plains_orc_warrior",
  picture: "",
  level: 16,
  family: "Orc",
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
    "Living"
  ],
  bcs: true,
  max_hp: 190,
  speed: 13,
  height: 7,
  size: "medium",
  areas: [
    {
      name: "Yegharren Plains",
      uids: [13034201..13034221, 13034301..13034338, 13034401..13034416]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Morning star",
        as: (176..180)
      },
      {
        name: "Handaxe",
        as: (140..180)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tackle"
      },
      {
        name: "Pounce"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16",
    immunities: [],
    melee: (78..185),
    ranged: (61..110),
    bolt: (61..110),
    udf: (112..188),
    bar_td: 48,
    cle_td: (45..51),
    emp_td: (48..56),
    pal_td: (42..54),
    ran_td: (45..54),
    sor_td: (48..54),
    wiz_td: nil,
    mje_td: (45..48),
    mne_td: (45..48),
    mjs_td: (66..75),
    mns_td: (66..75),
    mnm_td: (42..51),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a crude iron morning star",
    "a crude leather helm",
    "a heavy iron handaxe",
    "some heavy iron chainmail"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a scraggly orc scalp",
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "As tall as a giantman and twice as muscular as most, the plains orc warrior is taller and more agile than his more primitive orcish brothers, and judging by the cleverness in his beady yellow eyes, probably quite a bit more intelligent as well. Leathery brown skin covers his bulging limbs, the same color as the crude armor that protects his massive torso, and a scraggly red beard frames his heavy jowls."
    ],
    arrival: [
      "A plains orc warrior limps in all hunched over."
    ],
    flee: [
      "A plains orc warrior struts {direction}.",
      "A plains orc warrior hunches over and limps {direction}."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A plains orc warrior swings {weapon} at you!",
        "A plains orc warrior swings a crude iron morning star at {target}!",
        "A plains orc warrior swings a closed fist at {target}!",
        "A plains orc warrior swings {pronoun} heavy iron handaxe through the air in several impressive cut and thrust motions."
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
