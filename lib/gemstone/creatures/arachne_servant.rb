{
  schema_version: 3,
  name: "arachne servant",
  noun: "servant",
  url: "https://gswiki.play.net/arachne_servant",
  picture: "",
  level: 21,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 240,
  speed: 9,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Lower Trollfang",
      uids: [12016..12045]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Morning star",
        as: (150..190)
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
    asg: "5",
    immunities: [],
    melee: (131..282),
    ranged: (109..158),
    bolt: (109..158),
    udf: (228..263),
    bar_td: nil,
    cle_td: (63..67),
    emp_td: (73..81),
    pal_td: (66..76),
    ran_td: (63..73),
    sor_td: (63..76),
    wiz_td: nil,
    mje_td: (60..68),
    mne_td: (60..68),
    mjs_td: (73..79),
    mns_td: (73..79),
    mnm_td: (60..68),
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)",
      "Spirit Shield (202)",
      "Spell Shield (219)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a morning star",
    "a reinforced shield",
    "a visored helm",
    "some light leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "glimmering blue essence shard",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Dressed in a cassock and veil, the Arachne servant looks thin and malnourished. Staring from behind the veil are a pair of eyes that reflect both terror and determination. Bound to the service of Arachne, the Arachne servants are totally dedicated to their master, performing whatever duty is required."
    ],
    arrival: [
      "An Arachne servant just arrived."
    ],
    flee: [
      "An Arachne servant heads {direction}.",
      "An arachne servant looks tentative as {pronoun} backs away hissing, \"Repent! Lest Arachne strike thee down!\""
    ],
    death: [
      "The Arachne servant exhales a final curse and dies.",
      "The Arachne servant slumps to the ground and dies."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "An Arachne servant intones threateningly, \"Blasphemer! Infidel! Thou shalt know the eternal pain of Arachne!\""
    ],
    attacks: {
      attack: [
        "An Arachne servant swings {weapon} at you!"
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
