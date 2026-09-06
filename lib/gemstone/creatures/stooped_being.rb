{
  schema_version: 3,
  name: "stooped being",
  noun: "being",
  url: "https://gswiki.play.net/stooped_being",
  picture: "",
  level: 82,
  family: "Chimeric",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
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
      name: "Old Ta'Faendryl",
      uids: [17003011..17003038, 17003101..17003150, 17003201..17003217]
    },
    {
      name: "unmapped",
      uids: [17003001..17003010]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 406
      },
      {
        name: "Bite",
        as: (356..396)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Gaze"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 318,
    cle_td: nil,
    emp_td: nil,
    pal_td: 294,
    ran_td: nil,
    sor_td: (354..390),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 360,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
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
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The stooped being is a twisted amalgamation of flesh and other, less mentionable things. Skin that is sickly green gives way to an odd, jelly-like substance that covers most of the being's torso. A few extra, stunted arms and short, deformed tentacles protrude from the shoulders and back of the stooped being. The most terrifying part of this abomination's anatomy is the second head that sits in its chest, complete with a mouth, nose, and several dozen eyes."
    ],
    arrival: [
      "A stooped being hobbles in, looking about carefully.",
      "A stooped being stumbles in, the face in {pronoun} chest grinning wickedly."
    ],
    flee: [
      "A stooped being looks around, then hobbles {direction}.",
      "A stooped being hobbles {direction}, looking about carefully."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      claw: [
        "A stooped being claws at you!"
      ],
      bite: [
        "A stooped being tries to bite you!"
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
