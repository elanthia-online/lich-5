{
  schema_version: 3,
  name: "greater krynch",
  noun: "krynch",
  url: "https://gswiki.play.net/greater_krynch",
  picture: "",
  level: 84,
  family: "Krynch",
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
  max_hp: 300,
  speed: 16,
  height: 7,
  size: "medium",
  areas: [
    {
      name: "Bowels of Thanatoph",
      uids: [4293001..4293052]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound (attack)",
        as: 427
      },
      {
        name: "Fist",
        as: 427
      },
      {
        name: "Heavy earthen fists",
        as: 417
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Ethereal Wave"
      }
    ],
    special_abilities: [
      {
        name: "Krynch boulder"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "20N",
    immunities: [],
    melee: (217..438),
    ranged: (213..271),
    bolt: (213..271),
    udf: (450..653),
    bar_td: (306..315),
    cle_td: 341,
    emp_td: (323..332),
    pal_td: (279..282),
    ran_td: (288..294),
    sor_td: 345,
    wiz_td: nil,
    mje_td: 364,
    mne_td: 364,
    mjs_td: (360..366),
    mns_td: (360..366),
    mnm_td: (258..264),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a massive pitted iron pavis"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "luminescent silvery boulder opal",
    other: "essence of earth",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Veins of mica and quartz crystal run along and through the towering krynch's barrel chest and thick, powerful limbs, causing it to shimmer in even the dimmest light. A crown of rough rock and crystal spikes protrude from the top of its otherwise perfectly spherical head, adding to the creature's powerful stature. Its mouth is fixed in a perpetual scowl, and glossy black eyes glare at you with malevolent intensity."
    ],
    arrival: [
      "A massive boulder comes barrelling into view, abruptly rolls to a stop, and rises into the form of a greater krynch!",
      "The boulder comes to a sudden stop and rises into the form of a greater krynch!"
    ],
    flee: [
      "A greater krynch sinks into the ground, leaving no trace of {pronoun} passing."
    ],
    death: [
      "The greater krynch shudders, then topples to the ground.",
      "The greater krynch shudders violently for a moment, then goes still."
    ],
    decay: [
      "Tiny fissures quickly spread over a dead greater krynch, and it crumbles into rubble.",
      "Tiny fissures quickly spread over the entire form of an earth elemental.  Within moments, it crumbles into a pile of dirt and rubble."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A greater krynch pounds at you with {pronoun} fist!"
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
