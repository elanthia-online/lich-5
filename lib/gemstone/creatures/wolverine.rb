{
  schema_version: 3,
  name: "wolverine",
  noun: "wolverine",
  url: "https://gswiki.play.net/wolverine",
  picture: "",
  level: 24,
  family: "Mustelid",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
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
  max_hp: 210,
  speed: 15,
  height: 2,
  size: "small",
  areas: [
    {
      name: "Vornavian Coast",
      uids: [4214303..4214323]
    },
    {
      name: "Pinefar Forests",
      uids: [4563004..4563021]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 234
      },
      {
        name: "Claw",
        as: 234
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
    asg: "11N",
    immunities: [],
    melee: (187..241),
    ranged: (178..235),
    bolt: (178..235),
    udf: (199..225),
    bar_td: 72,
    cle_td: 74,
    emp_td: 76,
    pal_td: (69..72),
    ran_td: 72,
    sor_td: 79,
    wiz_td: nil,
    mje_td: (81..82),
    mne_td: (81..82),
    mjs_td: (124..131),
    mns_td: (124..131),
    mnm_td: 72,
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
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "a wolverine pelt",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Possessed with a ferocious nature far out of proportion to its size, this wolverine appears to be an extremely vicious opponent. Swift and agile, with claws and teeth backed by muscles like coiled springs, the wolverine will take on and defeat foes three times its size. Even stout boiled leather is oft times no match for its powerful claws and ferocious bite. There is commonly a touch of foam about its mouth, which may indicate some type of virulent disease."
    ],
    arrival: [
      "A wolverine scampers in."
    ],
    flee: [
      "The wolverine scampers {direction}."
    ],
    death: [
      "The wolverine falls back into a heap and dies.",
      "The wolverine hisses one last time and dies.",
      "The wolverine twitches violently, then dies."
    ],
    decay: [
      "A wolverine decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      claw: [
        "A wolverine claws at you!"
      ],
      bite: [
        "A wolverine tries to bite you!"
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
