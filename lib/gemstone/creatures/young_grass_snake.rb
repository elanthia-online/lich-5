{
  schema_version: 3,
  name: "young grass snake",
  noun: "snake",
  url: "https://gswiki.play.net/young_grass_snake",
  picture: "",
  level: 1,
  family: "Reptilian",
  type: "Ophidian",
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
  max_hp: 28,
  speed: 8,
  height: 1,
  size: "small",
  areas: [
    {
      name: "Rambling Meadows",
      uids: [14006001..14006020]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 23
      },
      {
        name: "Unknown",
        as: 23
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
    asg: "5N",
    immunities: [],
    melee: 23,
    ranged: (12..22),
    bolt: (12..22),
    udf: (32..41),
    bar_td: 3,
    cle_td: 3,
    emp_td: 3,
    pal_td: 3,
    ran_td: 3,
    sor_td: 3,
    wiz_td: nil,
    mje_td: 3,
    mne_td: 3,
    mjs_td: 3,
    mns_td: 3,
    mnm_td: 3,
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
    skin: "a snake skin",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Pale green and about a foot long, the grass snake relies on camouflage to avoid predators long enough to survive until adulthood. Though young, this creature is more deadly than its darker-in-color adult kin as it has yet to control its venom glands. Many an overconfident adventurer has died from the noxious poisons the grass snake is capable of delivering."
    ],
    arrival: [],
    flee: [
      "A young grass snake slithers {direction}."
    ],
    death: [],
    decay: [
      "A young grass snake decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      bite: [
        "A young grass snake tries to bite you!"
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
