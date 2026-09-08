{
  schema_version: 3,
  name: "huge mein golem",
  noun: "golem",
  url: "https://gswiki.play.net/huge_mein_golem",
  picture: "",
  level: 37,
  family: "Golem",
  type: "Biped",
  undead: false,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: false,
  sympathy: false,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Magical"
  ],
  bcs: true,
  max_hp: 331,
  speed: 10,
  height: 10,
  size: "huge",
  areas: [
    {
      name: "Darkstone Castle",
      uids: [44015..44018, 44020..44023, 45121..45127]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ensnare",
        as: 250
      },
      {
        name: "Heavy mein right fist",
        as: (234..255)
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
    asg: nil,
    immunities: [],
    melee: (133..151),
    ranged: (78..161),
    bolt: (78..161),
    udf: (215..352),
    bar_td: nil,
    cle_td: (129..132),
    emp_td: nil,
    pal_td: (108..117),
    ran_td: 111,
    sor_td: (133..142),
    wiz_td: nil,
    mje_td: 143,
    mne_td: 143,
    mjs_td: (124..130),
    mns_td: (124..130),
    mnm_td: (111..114),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: nil,
    other: "mein shards",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A towering, animated, glass-like creature, the huge mein golem is comprised entirely of mein. Taller than a giantman by half again and nearly as wide as tall, the mein golem displays a barrel chest, massive legs and arms, and a flattened, cylindrical head with almost no neck apparent. Animated by someone with a unique sense of humor, the huge mein golem contains many surprises for the unwary adventurer."
    ],
    arrival: [
      "A huge mein golem arrives, methodically striding forward.",
      "A huge mein golem strides in, a terrible creaking sound coming from cracks in its glass body."
    ],
    flee: [],
    death: [
      "The huge mein golem falls to the ground and stops moving."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A huge mein golem pounds at you with {pronoun} heavy mein right fist!",
        "A huge mein golem tries to ensnare you in {pronoun} solid mein arms!",
        "A huge mein golem pounds at you with {pronoun} heavy mein left fist!"
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
