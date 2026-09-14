{
  schema_version: 3,
  name: "striped relnak",
  noun: "relnak",
  url: "https://gswiki.play.net/striped_relnak",
  picture: "",
  level: 3,
  family: "Reptilian",
  type: "Quadruped",
  undead: false,
  blood: true,
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
  max_hp: 42,
  speed: 10,
  height: 1,
  size: "small",
  areas: [
    {
      name: "Rambling Meadows",
      uids: [14006021..14006040]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (31..61)
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
        name: "Foot",
        as: 61
      },
      {
        name: "Unknown",
        as: 41
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
    melee: (27..41),
    ranged: (36..37),
    bolt: (34..37),
    udf: (46..51),
    bar_td: 9,
    cle_td: 9,
    emp_td: 9,
    pal_td: (6..9),
    ran_td: 9,
    sor_td: 9,
    wiz_td: 9,
    mje_td: 9,
    mne_td: 9,
    mjs_td: (9..12),
    mns_td: (9..12),
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
    skin: "a striped relnak sail",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The striped relnak is a low-slung, wide-bodied reptile of the chameleon family. Only a few feet long, it is deceptively fast despite its girth. Its skin is scaly and rough with alternating strips of red and charcoal grey, except for the flaring, spiny sail that stands erect on its back which is solid grey. Extending from its thick neck to nearly the tip of its flicking tail, the sail's charcoal grey is punctuated by evenly spaced iridescent blue spines which glow brightly when the relnak is agitated."
    ],
    arrival: [
      "A striped relnak scampers in.",
      "A striped relnak charges into the area!"
    ],
    flee: [
      "The relnak scampers {direction}."
    ],
    death: [
      "The striped relnak hisses one last time and dies.",
      "The striped relnak falls back into a heap and dies."
    ],
    decay: [
      "A striped relnak decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A striped relnak stomps at you with {pronoun} foot!"
      ],
      bite: [
        "A striped relnak tries to bite you!"
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
