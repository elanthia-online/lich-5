{
  schema_version: 3,
  name: "skeletal soldier",
  noun: "soldier",
  url: "https://gswiki.play.net/skeletal_soldier",
  picture: "",
  level: 34,
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
  max_hp: 300,
  speed: 11,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Miasmal Forest",
      uids: [5003001..5003027, 5003030..5003030, 5003032..5003032, 5003036..5003039, 5004016..5004034]
    },
    {
      name: "unmapped",
      uids: [5003028..5003029, 5003031..5003031, 5003033..5003035]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Disarm Weapon"
      },
      {
        name: "Crude black iron morning star",
        as: 224
      },
      {
        name: "Claw",
        as: 207
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (217..251),
    ranged: (193..223),
    bolt: (193..223),
    udf: (242..303),
    bar_td: (102..111),
    cle_td: (108..114),
    emp_td: (109..116),
    pal_td: (102..111),
    ran_td: (102..111),
    sor_td: (115..124),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 121,
    mjs_td: (109..118),
    mns_td: (109..118),
    mnm_td: (102..105),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a crude black iron morning star",
    "some decaying grey-hued leathers"
  ],
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
      "Clad in broken chain armor, the soldier's pale white bones are exposed in certain points in which the armor has completely rusted away. Dark leather gloves cover its bony hands. A very small glimmer of life can be seen in the depths of the soldier's eye sockets."
    ],
    arrival: [],
    flee: [
      "A skeletal soldier clatters {direction}.",
      "A skeletal soldier backs away.",
      "A skeletal soldier backs away with {pronoun} iron morning star dragging along the ground in front of {pronoun}.",
      "A skeletal soldier backs away with {pronoun} {weapon} dragging along the ground in front of {pronoun}."
    ],
    death: [
      "The skeletal soldier struggles to rise to its feet, but soon lies still.",
      "The skeletal soldier falls to the ground dead, {pronoun} calcified bones still pulsating with a blinding white hue."
    ],
    decay: [
      "A skeletal soldier crumbles to a fine white powder."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A skeletal soldier swings {weapon} at you!",
        "A skeletal soldier swings a crude black iron morning star at {target}!"
      ],
      claw: [
        "A skeletal soldier claws at you!"
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
