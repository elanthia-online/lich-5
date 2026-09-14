{
  schema_version: 3,
  name: "rock troll zombie",
  noun: "zombie",
  url: "https://gswiki.play.net/rock_troll_zombie",
  picture: "",
  level: 34,
  family: "Troll",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Corporeal undead",
    "Boss"
  ],
  bcs: true,
  max_hp: 388,
  speed: 8,
  height: 11,
  size: "huge",
  areas: [
    {
      name: "Troll Burial Grounds",
      uids: [13011001..13011035]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (227..245)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tackle"
      },
      {
        name: "Disarm Weapon"
      },
      {
        name: "Disarm"
      },
      {
        name: "Pounce"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16N",
    immunities: [],
    melee: (77..268),
    ranged: (102..158),
    bolt: (102..158),
    udf: (290..373),
    bar_td: nil,
    cle_td: (116..119),
    emp_td: (117..127),
    pal_td: (99..108),
    ran_td: (102..111),
    sor_td: (123..132),
    wiz_td: nil,
    mje_td: (123..138),
    mne_td: (123..138),
    mjs_td: (117..126),
    mns_td: (117..126),
    mnm_td: (96..105),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a granite greathelm",
    "some granite bracers",
    "some granite leg guards"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a decaying troll eye",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A rock troll zombie is a towering sight to behold. Standing well over the height of two giantkin combined, the troll zombie is clad in rock armor, composed entirely of granite. Golden embers burn with a hatred of life out from under the zombie's massive granite helm."
    ],
    arrival: [
      "A rock troll zombie lumbers in!",
      "A rock troll zombie lumbers in, limping slightly!",
      "A rock troll zombie limps in with a scowl upon {pronoun} brow!"
    ],
    flee: [
      "A rock troll zombie lumbers {direction}.",
      "A rock troll zombie lumbers {direction} with a slight limp.",
      "A rock troll zombie grimaces and slowly limps {direction}.",
      "A rock troll zombie lumbers {direction}, limping slightly!"
    ],
    death: [
      "The troll zombie tears off a piece of {pronoun} flesh, gnawing upon the decayed meat in a vain attempt to nourish {pronoun} continued tormented existence.  With the attempt failing, the troll zombie slumps to the ground motionless.",
      "The troll zombie tears off a piece of {pronoun} flesh, gnawing upon the decayed meat in a vain attempt to nourish {pronoun} continued tormented existence.  With the attempt failing, the troll zombie topples to the ground motionless."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      claw: [
        "A rock troll zombie claws at you!"
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
