{
  schema_version: 3,
  name: "twisted being",
  noun: "being",
  url: "https://gswiki.play.net/twisted_being",
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
        name: "Bite",
        as: (356..396)
      },
      {
        name: "Claw",
        as: 396
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Firebreathing"
      },
      {
        name: "Lash"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 346,
    cle_td: nil,
    emp_td: nil,
    pal_td: 281,
    ran_td: nil,
    sor_td: (354..390),
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Defense (103)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)",
      "Lesser Shroud (120)",
      "Prismatic Guard (905)",
      "Mass Blur (911)"
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
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The twisted being is a twisted amalgamation of flesh and other, less mentionable things. The chalky white skin of this being is rough and pebbly, similar to a reptile's. Two beady black eyes peer out from a snake-shaped head that is topped with a twisted, spiked crest which runs all the way down the being's spine and along its whip-like tail. Row upon row of deadly, razor-sharp teeth fill the being's mouth, and saliva drips from its thick purple tongue."
    ],
    arrival: [
      "A twisted being stalks in, its tail swishing back and forth menacingly.",
      "A twisted being comes darting in."
    ],
    flee: [
      "A twisted being stoops low and darts {direction}.",
      "A twisted being quickly limps {direction}."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [
      "A twisted being rumbles a series of arcane phrases."
    ],
    attacks: {
      claw: [
        "A twisted being claws at you!"
      ],
      bite: [
        "A twisted being tries to bite you!"
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
