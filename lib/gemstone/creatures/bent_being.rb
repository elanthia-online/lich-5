{
  schema_version: 3,
  name: "bent being",
  noun: "being",
  url: "https://gswiki.play.net/bent_being",
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
        name: "Stomp",
        as: 386
      },
      {
        name: "Claw",
        as: 356
      },
      {
        name: "Foot",
        as: 386
      }
    ],
    bolt_spells: [
      {
        name: "Major Shock (910)",
        as: 374
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
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
    bar_td: (315..345),
    cle_td: nil,
    emp_td: nil,
    pal_td: 253,
    ran_td: nil,
    sor_td: (354..390),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 390,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I",
      "Elemental Defense II",
      "Elemental Defense III",
      "Mass Blur (911)",
      "Prismatic Guard (905)",
      "Thurfel's Ward (503)"
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
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The bent being is a twisted amalgamation of flesh and other, less mentionable things. Stark white hair grows in random patches from the being's sickly green skin, especially around its face. The bent being has over-sized ears that look comical on an otherwise intimidating foe. Thick legs sprout from the being's midsection like tree trunks, ending in gigantic feet that could fit in no boot made for civilized creatures."
    ],
    arrival: [
      "A bent being comes rumbling in.",
      "A bent being comes in, a crackle of lightning briefly surrounding it."
    ],
    flee: [
      "A bent being rumbles {direction}."
    ],
    death: [
      "A bent being curses through its teeth as it dies."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A bent being rumbles a series of arcane phrases."
    ],
    attacks: {
      attack: [
        "A bent being cries out in an acidic tongue, pointing at you!",
        "A bent being stomps at you with {pronoun} foot!"
      ],
      claw: [
        "A bent being claws at you!"
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
