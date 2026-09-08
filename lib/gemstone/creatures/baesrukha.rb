{
  schema_version: 3,
  name: "baesrukha",
  noun: "baesrukha",
  url: "https://gswiki.play.net/baesrukha",
  picture: "",
  level: 42,
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
  max_hp: 238,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Yegharren Plains",
      uids: [13036401..13036414, 13036501..13036514]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (247..273)
      },
      {
        name: "Bite",
        as: (187..262)
      },
      {
        name: "Roaring ball of fire",
        as: 220
      }
    ],
    bolt_spells: [
      {
        name: "Major Fire (908)",
        as: 220
      }
    ],
    warding_spells: [
      {
        name: "Cold Snap (512)"
      },
      {
        name: "Elemental Blast (409)",
        cs: 212
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (118..303),
    ranged: (172..195),
    bolt: (172..195),
    udf: (157..330),
    bar_td: (140..153),
    cle_td: (158..165),
    emp_td: (158..167),
    pal_td: (135..144),
    ran_td: (135..138),
    sor_td: (162..179),
    wiz_td: nil,
    mje_td: (173..188),
    mne_td: (173..188),
    mjs_td: (161..168),
    mns_td: (161..168),
    mnm_td: (143..152),
    defensive_spells: [
      "Elemental Defense I",
      "Elemental Defense II",
      "Elemental Defense III",
      "Thurfel's Ward",
      "Elemental Bias"
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
    other: [
      "Glowing violet essence dust",
      "glowing violet essence shard"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Her emaciated form roughly humanoid, the baesrukha glides along the ground, clawing at the air with bloodied talons. Her burning red eyes stare malevolently at any intruder, gazing out from a nearly featureless face above a fanged, lipless mouth. Whitish tendrils of ectoplasm coil and whip around her tattered robes, writhing in the miasma that surrounds the ancient wraithlike creature like hungry snakes."
    ],
    arrival: [
      "A baesrukha sweeps in, {pronoun} haunted eyes darting about."
    ],
    flee: [],
    death: [
      "The baesrukha collapses to the ground in a motionless heap, sending a plume of dust up from {pronoun} unwashed body."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A baesrukha closes {pronoun} eyes and holds {pronoun} palm out towards you!"
    ],
    attacks: {
      bite: [
        "A baesrukha tries to bite you!"
      ],
      claw: [
        "A baesrukha claws at you!"
      ],
      hurl: [
        "A baesrukha hurls {weapon} at you!"
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
