{
  schema_version: 3,
  name: "fallen crusader",
  noun: "crusader",
  url: "https://gswiki.play.net/fallen_crusader",
  picture: "",
  level: 97,
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
    "Non-corporeal undead",
    "Extraplanar"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "The Rift",
      uids: [4569001..4569023]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Barbed tentacle",
        as: (428..450)
      },
      {
        name: "Gilt-edged steel talon sword",
        as: (506..515)
      },
      {
        name: "Gold-spiked black morning star",
        as: (440..506)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Gilt-edged steel talon sword",
        cs: 411
      },
      {
        name: "Gold-spiked black morning star",
        cs: 408
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Charge"
      },
      {
        name: "Feint"
      },
      {
        name: "Shield Charge"
      },
      {
        name: "Tail Swipe"
      },
      {
        name: "Gesture"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16",
    immunities: [],
    melee: (338..585),
    ranged: (307..501),
    bolt: (307..501),
    udf: (399..716),
    bar_td: (338..360),
    cle_td: (361..371),
    emp_td: (373..383),
    pal_td: (317..326),
    ran_td: (320..329),
    sor_td: 392,
    wiz_td: nil,
    mje_td: 411,
    mne_td: 411,
    mjs_td: (423..425),
    mns_td: (423..425),
    mnm_td: (296..315),
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)",
      "Fasthr's Reward (115)",
      "Lesser Shroud (120)",
      "Mantle of Faith (1601)",
      "Divine Shield (1609)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a gilt-edged steel talon sword",
    "a gold-spiked black morning star",
    "a pitted golden chain hauberk",
    "a reinforced dark steel kite shield"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Inky necrotic core",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Roiling wisps of ethereal green mist fill in the form of a muscled warrior. Fleshy tones, segments of armor, and humanoid features flicker across her visage, as if the mist was remembering bits and pieces of the paladin's former body, if for only moments at a time. Unable to hold corporeal form, the only meaningful remnants of the crusader's prior existence are her stark conviction, held now in eyes which are no more than swirling grey voids, and her martial prowess."
    ],
    arrival: [
      "A fallen crusader just arrived, looking terrified!"
    ],
    flee: [
      "A fallen crusader bolts {direction}!",
      "A fallen crusader trots {direction}, {pronoun} spectral armor clattering with each stride."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [
      "A fallen crusader's eyes glow with silvery grey light, and then everything around you shimmers to match the argentine color.",
      "A fallen crusader gestures sharply toward {target}!",
      "A fallen crusader's eyes begin to glow purple."
    ],
    attacks: {
      attack: [
        "A fallen crusader swings {weapon} at you!",
        "A fallen crusader swings a gilt-edged steel talon sword at {target}!",
        "The fallen crusader slams into {target}, who is sent careening into another {target}!",
        "A fallen crusader swings a gold-spiked black morning star at {target}!",
        "The fallen crusader slams into you, and you are sent careening to the ground!"
      ],
      shield_charge: [
        "A fallen crusader charges forward at you with {pronoun} dark steel kite shield and attempts a shield charge!"
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
