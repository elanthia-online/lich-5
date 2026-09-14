{
  schema_version: 3,
  name: "arachne priest",
  noun: "priest",
  url: "https://gswiki.play.net/arachne_priest",
  picture: "",
  level: 26,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: "miniboss",
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 210,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Spider Temple",
      uids: [13001..13036]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Broadsword",
        as: 219
      },
      {
        name: "Scimitar",
        as: 294
      },
      {
        name: "Short sword",
        as: 266
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Web (118)",
        cs: 118
      }
    ],
    offensive_spells: [
      {
        name: "Spirit Strike (117)"
      },
      {
        name: "Heroism (215)"
      },
      {
        name: "Benediction (307)"
      }
    ],
    maneuvers: [
      {
        name: "Point"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (179..261),
    ranged: (160..238),
    bolt: (180..238),
    udf: 205,
    bar_td: 92,
    cle_td: 102,
    emp_td: (96..104),
    pal_td: (85..95),
    ran_td: nil,
    sor_td: (106..115),
    wiz_td: 107,
    mje_td: 107,
    mne_td: 107,
    mjs_td: (101..104),
    mns_td: (101..104),
    mnm_td: (111..118),
    defensive_spells: [
      "Spirit Warding II (107)",
      "Spell Shield (219)",
      "Prayer of Protection (303)",
      "Warding Sphere (310)",
      "Prayer (313)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a reinforced shield",
    "a scimitar",
    "a short sword"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Glimmering blue essence shard",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The Arachne priest's lithe body is covered by heavy silk robes that also cowl most of the facial features. A single visible image of a black spider over a crimson background is clearly emblazoned upon the backside. Draped in their macabre attire, the Arachne priest goes about its zealous duties in worship of Arachne. Upon close inspection, one can make out partial shapes of sigils formed by welts and mutilations on the hands and face."
    ],
    arrival: [
      "An Arachne priest just arrived.",
      "An Arachne priestess just arrived.",
      "An Arachne priest strolls in chanting a soft prayer to {pronoun} god!"
    ],
    flee: [
      "An Arachne priest heads {direction}.",
      "An Arachne priestess heads {direction}."
    ],
    death: [
      "The Arachne priest exhales a final curse and dies.",
      "The Arachne priest slumps to the ground and dies.",
      "The Arachne priestess exhales a final curse and dies."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "An Arachne priest gestures!"
    ],
    attacks: {
      attack: [
        "An Arachne priest swings {weapon} at you!"
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
