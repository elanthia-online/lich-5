{
  schema_version: 3,
  name: "krolvin corsair",
  noun: "corsair",
  url: "https://gswiki.play.net/krolvin_corsair",
  picture: "",
  level: 38,
  family: "Krolvin",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: 8,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Shattered Moors",
      uids: [420501..420542]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Tackle"
      },
      {
        name: "Plain steel cutlass",
        as: 228
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (141..273),
    ranged: (164..211),
    bolt: (164..211),
    udf: (199..311),
    bar_td: (108..114),
    cle_td: (108..120),
    emp_td: (114..123),
    pal_td: (111..123),
    ran_td: (114..123),
    sor_td: (105..123),
    wiz_td: nil,
    mje_td: (112..130),
    mne_td: (112..130),
    mjs_td: (105..123),
    mns_td: (105..123),
    mnm_td: (114..117),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a plain steel cutlass",
    "a salt-encrusted knapsack",
    "a suit of chain hauberk"
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
      "More muscular and agile than the average krolvin, the corsair's distinctive rolling gait is evidence of a life spent seafaring. His sturdy musculature is apparent beneath the grey-blue skin. Thick, coarse, white hair covers his head and spreads across his shoulders and down his back."
    ],
    arrival: [
      "A krolvin corsair just came through an oaken hatchway.",
      "A krolvin corsair just came through an iron-banded door."
    ],
    flee: [
      "A krolvin corsair stumps {direction}.",
      "A krolvin corsair just went through an oaken hatchway.",
      "A krolvin corsair just went through an iron-banded door.",
      "A krolvin corsair just went through a portside door."
    ],
    death: [
      "The krolvin corsair tries to crawl away on the deck but collapses and goes still."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A krolvin corsair hisses between gaping teeth as {pronoun} struggles with {pronoun} thoughts.",
      "A krolvin corsair hisses between gaping teeth as {pronoun} struggles with {pronoun} {weapon}."
    ],
    attacks: {
      attack: [
        "A krolvin corsair swings {weapon} at you!"
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
