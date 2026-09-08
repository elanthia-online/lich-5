{
  schema_version: 3,
  name: "gnarled being",
  noun: "being",
  url: "https://gswiki.play.net/gnarled_being",
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
        name: "Impale",
        as: 396
      },
      {
        name: "Smash",
        as: (398..412)
      },
      {
        name: "Tusk",
        as: 356
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Ground Slam"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: 509,
    ranged: (339..364),
    bolt: (339..364),
    udf: 381,
    bar_td: (315..335),
    cle_td: nil,
    emp_td: (335..341),
    pal_td: (294..297),
    ran_td: nil,
    sor_td: (354..390),
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 392,
    mns_td: 392,
    mnm_td: (276..285),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: [
      "Hides when attacked"
    ]
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
    other: "Radiant crimson mote of essence",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The gnarled being is a twisted amalgamation of flesh and other, less mentionable things. Tusks and horns grow from its head in an impressive array of weaponry. The tough, pale yellow skin of the being looks burnt and scorched in places, but this doesn't seem to bother it. The gnarled being's twisted hands and feet end with wicked, razor-sharp claws that refuse to shine in the light."
    ],
    arrival: [
      "A gnarled being strides in with a snort of derision."
    ],
    flee: [],
    death: [
      "A gnarled being coughs up some blood and dies.",
      "A gnarled being crashes to the ground, dead."
    ],
    decay: [
      "A gnarled being crumbles away into nothing."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A gnarled being snorts as {pronoun} tries to regain {pronoun} senses."
    ],
    attacks: {
      attack: [
        "A gnarled being charges at you with {pronoun} tusk!"
      ],
      claw: [
        "A gnarled being claws at you!"
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
