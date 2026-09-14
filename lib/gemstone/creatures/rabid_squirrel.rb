{
  schema_version: 3,
  name: "rabid squirrel",
  noun: "squirrel",
  url: "https://gswiki.play.net/rabid_squirrel",
  picture: "",
  level: 2,
  family: "Rodent",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 36,
  speed: 6,
  height: 1,
  size: "small",
  areas: [
    {
      name: "Lower Dragonsclaw",
      uids: [372030..372039, 373017..373019, 373022..373024]
    },
    {
      name: "Southern Snowfields",
      uids: [4128007..4128011]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Nip (attack)"
      },
      {
        name: "Nip",
        as: (36..46)
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
    melee: (23..29),
    ranged: (17..27),
    bolt: (17..27),
    udf: 48,
    bar_td: nil,
    cle_td: 6,
    emp_td: 6,
    pal_td: 6,
    ran_td: 6,
    sor_td: 6,
    wiz_td: nil,
    mje_td: 6,
    mne_td: 6,
    mjs_td: 6,
    mns_td: 6,
    mnm_td: 6,
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
    skin: "a squirrel tail",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A rabid squirrel is twice the size of your average squirrel. Its beady little eyes are blood-shot and watery and its mangy coat is a lusterless grey. The evil little creature slavers constantly and moves with terrifying speed."
    ],
    arrival: [
      "A rabid squirrel scampers in, foam dripping from its mouth!",
      "A rabid squirrel scampers in!"
    ],
    flee: [
      "A rabid squirrel scampers {direction}.",
      "A rabid squirrel chatters as {pronoun} slowly backs away."
    ],
    death: [
      "The rabid squirrel twitches its tail one last time and dies."
    ],
    decay: [
      "A rabid squirrel decays into a pile of hair and bone."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A rabid squirrel staggers as {pronoun} tries to regain {pronoun} bearings!"
    ],
    attacks: {
      attack: [
        "A rabid squirrel nips at you!"
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
