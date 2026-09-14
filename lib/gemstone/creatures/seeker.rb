{
  schema_version: 3,
  name: "seeker",
  noun: "seeker",
  url: "https://gswiki.play.net/seeker",
  picture: "",
  level: 52,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 240,
  speed: 10,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Great Mountain Aenatumgana",
      uids: [4561101..4561141]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Earthen Fury (917)"
      },
      {
        name: "Gas cloud"
      },
      {
        name: "Strength (509)"
      },
      {
        name: "Elemental Dispel"
      },
      {
        name: "Ancient walking stick",
        as: (243..271)
      }
    ],
    maneuvers: [
      {
        name: "Skeletal Finger"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1",
    immunities: [],
    melee: (286..388),
    ranged: (258..332),
    bolt: (258..337),
    udf: (335..456),
    bar_td: nil,
    cle_td: (203..212),
    emp_td: (219..228),
    pal_td: (192..201),
    ran_td: (184..190),
    sor_td: (224..233),
    wiz_td: nil,
    mje_td: (227..246),
    mne_td: (227..246),
    mjs_td: (196..201),
    mns_td: (196..201),
    mnm_td: (175..187),
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Mass Blur (911)",
      "Prismatic Guard (905)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a rotting tattered robe",
    "an ancient walking stick"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a seeker eye",
    other: "Glowing violet mote of essence",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Approaching from afar, the seeker looks for all the world like a hunched over traveller, barely getting by with the aid of her walking stick, shuffling along and muttering to herself. Upon close examination, though, the seeker projects a grisly visage of skeletal madness. Some strange magic has caused her eyelids to grow completely over her eyes, rendering her blind, yet the rest of her face is totally fleshless. Grinning fiendishly, the seeker unerringly pursues her goal - the Eye of the Drake and the path through to the Rift."
    ],
    arrival: [],
    flee: [
      "A seeker moans as she shuffles {direction}."
    ],
    death: [
      "The seeker mutters, \"...the Eye, the Eye...\" and lies still."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A seeker swings {weapon} at you!"
      ],
      bolt: [
        "A seeker hurls a stream of fire at {target}!"
      ],
      cast: [
        "A seeker points a skeletal finger at you!"
      ],
      hurl: [
        "A seeker hurls a large boulder at {target}!"
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
