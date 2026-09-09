{
  schema_version: 3,
  name: "krolvin warfarer",
  noun: "warfarer",
  url: "https://gswiki.play.net/krolvin_warfarer",
  picture: "",
  level: 25,
  family: "Krolvin",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 281,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Sea Caves",
      uids: [26001..26036, 26101..26120]
    },
    {
      name: "Lysierian Hills",
      uids: [93071..93079, 485001..485011]
    },
    {
      name: "Luinne Bheinn",
      uids: [4251017..4251056]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Awl-pike",
        as: 200
      },
      {
        name: "Claidhmore",
        as: 200
      },
      {
        name: "Falchion",
        as: (162..200)
      },
      {
        name: "Morning star",
        as: 196
      },
      {
        name: "Broadsword",
        as: 204
      }
    ],
    bolt_spells: [
      {
        name: "Fire Spirit (111)",
        as: 179
      }
    ],
    warding_spells: [
      {
        name: "Elemental Blast (409)",
        cs: 127
      },
      {
        name: "Unbalance (110)",
        cs: 130
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Wave (410)"
      }
    ],
    maneuvers: [
      {
        name: "Gesture"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (128..267),
    ranged: (117..212),
    bolt: (120..212),
    udf: 126,
    bar_td: (63..89),
    cle_td: (81..89),
    emp_td: (80..88),
    pal_td: (67..76),
    ran_td: (70..78),
    sor_td: (84..94),
    wiz_td: nil,
    mje_td: (85..101),
    mne_td: (85..101),
    mjs_td: (77..86),
    mns_td: (77..86),
    mnm_td: (82..91),
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Spirit Defense (103)",
      "Spirit Fog (106)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a falchion",
    "a reinforced shield",
    "some full leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Glimmering blue essence shard",
      "t'ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "As tall as the average human, the warfarer has the characteristic long-fingered hands and sturdy musculature that denote most of the krolvin race. The warfarer also sports the trademark grey-blue skin and thick, coarse, white hair covers his head and spreads across his shoulders and down his back."
    ],
    arrival: [
      "A krolvin warfarer suddenly trots into view!"
    ],
    flee: [
      "A krolvin warfarer stumps {direction}.",
      "A belligerent krolvin warfarer stumps {direction}."
    ],
    death: [
      "The krolvin warfarer twitches violently, then dies.",
      "The krolvin warfarer rolls over on the floor and goes still."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A krolvin warfarer gestures at {target}!"
    ],
    stun_break: [
      "A krolvin warfarer fidgets and twitches {pronoun} lips as {pronoun} struggles to regain {pronoun} composure."
    ],
    attacks: {
      attack: [
        "A krolvin warfarer gestures at you!",
        "A krolvin warfarer swings {weapon} at you!",
        "A krolvin warfarer swings a broadsword at {target}!"
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
