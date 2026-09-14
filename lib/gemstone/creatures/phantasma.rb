{
  schema_version: 3,
  name: "phantasma",
  noun: "phantasma",
  url: "https://gswiki.play.net/phantasma",
  picture: "",
  level: 42,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: nil,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 240,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Castle Varunar",
      uids: [4750053..4750069]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Leather whip",
        as: 217
      },
      {
        name: "Barbed whip",
        as: 237
      },
      {
        name: "Splintered lance",
        as: 227
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Corrupt Essence (703)",
        cs: 201
      },
      {
        name: "Disintegrate (705)",
        cs: 195
      },
      {
        name: "Pain (711)",
        cs: 207
      },
      {
        name: "Curse (715)",
        cs: 201
      },
      {
        name: "Point",
        cs: 210
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Moan"
      },
      {
        name: "Point"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "5",
    immunities: [],
    melee: (150..268),
    ranged: (167..254),
    bolt: (167..254),
    udf: (258..391),
    bar_td: (130..135),
    cle_td: (161..164),
    emp_td: (153..163),
    pal_td: (137..140),
    ran_td: (125..133),
    sor_td: (160..185),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 169,
    mjs_td: (163..169),
    mns_td: (163..169),
    mnm_td: (142..150),
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)",
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a barbed whip",
    "a wickedly curved scimitar",
    "some rotted leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Glowing violet mote of essence",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A barely visible spirit, the phantasma floats silently across the room. Its bald head, thick neck, muscular forearms and fixed sneer reflect its former positions of jailer and torturer. Rotting leather armor drapes the phantasma, providing it with its only solid link to the living past."
    ],
    arrival: [],
    flee: [
      "A phantasma floats {direction}."
    ],
    death: [
      "A phantasma fades into oblivion."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A phantasma gestures and utters a phrase of arcane magic."
    ],
    attacks: {
      attack: [
        "A phantasma swings {weapon} at you!",
        "A phantasma thrusts with a splintered lance at you!"
      ],
      cast: [
        "A phantasma points a ghostly finger at {target}!"
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
