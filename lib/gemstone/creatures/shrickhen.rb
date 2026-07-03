{
  schema_version: 3,
  name: "shrickhen",
  noun: "",
  url: "https://gswiki.play.net/shrickhen",
  picture: "",
  level: 76,
  family: "Chimeric",
  type: "Hybrid",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Corporeal undead",
    "Magical"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Blighted Forest",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 367
      },
      {
        name: "Claw",
        as: (365..392)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Elemental Dispel (417)"
      },
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Major Elemental Wave (435)"
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
    ranged: nil,
    bolt: 285,
    udf: nil,
    bar_td: (281..285),
    cle_td: (295..320),
    emp_td: nil,
    pal_td: 260,
    ran_td: nil,
    sor_td: (306..338),
    wiz_td: nil,
    mje_td: 344,
    mne_td: nil,
    mjs_td: nil,
    mns_td: (290..315),
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense II",
      "Elemental Defense III",
      "Elemental Targetting"
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
    skin: "No",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Seemingly cobbled together from leftover bodily parts, no two shrickhen are alike.  One may have the lower body of a troll supporting the torso of a fire salamander from which a dark orc's arm extends on one side and a gremlin's arm extends on the other, all topped by a timberwolf's head.  A second may have a mezic's leg, a coyote's leg, a pyrothag's arm, and a shan warrior's arm, each connected in almost the right place to the torso of a krolvin warfarer, with the entire grouping utilizing the one-eyed head of a cyclops for navigation.  These hideous conglomerations definitely have two things in common: a total lack of fear and an insatiable need to consume flesh.</pre>"
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
