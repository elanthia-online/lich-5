{
  schema_version: 3,
  name: "spectral lord",
  noun: "lord",
  url: "https://gswiki.play.net/spectral_lord",
  picture: "",
  level: 36,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
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
  bcs: true,
  max_hp: 300,
  speed: 6,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Wraithenmist",
      uids: [13027044..13027086]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ball and chain",
        as: 250
      },
      {
        name: "Morning star",
        as: (222..250)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Disarm Weapon"
      },
      {
        name: "Disarm"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (159..199),
    ranged: (146..171),
    bolt: (146..171),
    udf: (226..258),
    bar_td: 108,
    cle_td: (108..114),
    emp_td: (108..117),
    pal_td: (108..114),
    ran_td: (108..114),
    sor_td: (108..114),
    wiz_td: 114,
    mje_td: nil,
    mne_td: (113..119),
    mjs_td: (110..120),
    mns_td: (110..120),
    mnm_td: (102..108),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a battered",
    "a black steel ball & chain",
    "a modwir hafted morning star",
    "a reinforced shield",
    "a rotting leather breastplate",
    "some rusted double chain"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: nil,
    other: "Glowing violet essence shard",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "But a shade of its original self, the spectral lord is a dim and flickering image of a noble. Sharp, hawk-like features, and narrowed brilliant eyes give the appearance of a keen intellect. Worn and rotting gear hangs from its body, deteriorating from centuries of disuse."
    ],
    arrival: [],
    flee: [
      "A spectral lord floats {direction}."
    ],
    death: [
      "A spectral lord dissipates into ethereal wisps."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A spectral lord swings {weapon} at you!",
        "A spectral lord swings {pronoun} {weapon} at your vultite handaxe!",
        "A spectral lord swings {pronoun} black steel ball & chain at your vultite handaxe!",
        "A spectral lord swings {pronoun} {weapon} at your mossbark runestaff!"
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
