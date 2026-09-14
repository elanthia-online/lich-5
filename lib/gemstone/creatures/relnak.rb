{
  schema_version: 3,
  name: "relnak",
  noun: "relnak",
  url: "https://gswiki.play.net/relnak",
  picture: "",
  level: 3,
  family: "Reptilian",
  type: "Quadruped",
  undead: false,
  blood: nil,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 44,
  speed: 10,
  height: 1,
  size: "small",
  areas: [
    {
      name: "Catacombs",
      uids: [490002..490004, 490010..490011, 490018..490018]
    },
    {
      name: "unmapped",
      uids: [490017..490017]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 61
      },
      {
        name: "Charge (attack)",
        as: 71
      },
      {
        name: "Stomp",
        as: 61
      },
      {
        name: "Charge",
        as: 71
      },
      {
        name: "Foot",
        as: 61
      },
      {
        name: "Unknown",
        as: 71
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (36..61),
    ranged: (34..57),
    bolt: (34..57),
    udf: (41..46),
    bar_td: nil,
    cle_td: 9,
    emp_td: 9,
    pal_td: (6..9),
    ran_td: 9,
    sor_td: 9,
    wiz_td: nil,
    mje_td: 9,
    mne_td: 9,
    mjs_td: 9,
    mns_td: 9,
    mnm_td: 9,
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
    coins: true,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a relnak sail",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The relnak is a low-slung, wide-bodied reptile of the chameleon family. Only a few feet long, it is deceptively fast despite its girth. Its skin is scaly, rough, and a uniform charcoal grey, except for the flaring, spiny sail that stands erect on its back. Extending from its thick neck to nearly the tip of its flicking tail, the sail's charcoal grey is punctuated by evenly spaced iridescent blue spines which glow brightly when the relnak is agitated."
    ],
    arrival: [
      "A relnak scampers in."
    ],
    flee: [
      "The relnak scampers {direction}."
    ],
    death: [
      "The relnak falls back into a heap and dies.",
      "The relnak hisses one last time and dies."
    ],
    decay: [
      "A relnak decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A relnak charges at you!",
        "A relnak stomps at you with {pronoun} foot!"
      ],
      bite: [
        "A relnak tries to bite you!"
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
