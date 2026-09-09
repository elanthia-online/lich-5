{
  schema_version: 3,
  name: "cockatrice",
  noun: "cockatrice",
  url: "https://gswiki.play.net/cockatrice",
  picture: "",
  level: 6,
  family: "Basilisk",
  type: "Hybrid",
  undead: false,
  blood: nil,
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
  max_hp: 69,
  speed: 10,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Upper Trollfang",
      uids: [15009..15015]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw (attack)",
        as: 99
      },
      {
        name: "Pincer (attack)",
        as: 99
      },
      {
        name: "Charge (attack)",
        as: 109
      },
      {
        name: "Strike",
        as: (80..99)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Dust Kick"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1",
    immunities: [],
    melee: (38..114),
    ranged: (26..64),
    bolt: (26..64),
    udf: (85..138),
    bar_td: nil,
    cle_td: 18,
    emp_td: 18,
    pal_td: (15..18),
    ran_td: 18,
    sor_td: 18,
    wiz_td: nil,
    mje_td: 18,
    mne_td: 18,
    mjs_td: 57,
    mns_td: 57,
    mnm_td: 18,
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
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a cockatrice feather",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A smaller relative of the basilisk, the cockatrice has a serpentine body, with feathered head, wings, and legs. Having the cold, freezing gaze of its larger cousin, the cockatrice should not be treated lightly. A sharp beak and raking claws complete this small but deadly package of evil."
    ],
    arrival: [
      "A cockatrice just arrived!"
    ],
    flee: [
      "A cockatrice limps {direction}.",
      "A cockatrice thunders {direction}."
    ],
    death: [
      "The cockatrice rolls over on its back, emits a final screech and dies."
    ],
    decay: [
      "A cockatrice decays into a useless pile of scales and feathers."
    ],
    search: [],
    spell_prep: [],
    stand: [
      "A cockatrice screeches loudly as {pronoun} scrambles to {pronoun} feet!"
    ],
    attacks: {
      attack: [
        "A cockatrice screeches and strikes at you!",
        "A cockatrice attempts to kick mud at you, but is unable to kick up a sufficient amount of mud.",
        "A cockatrice attempts to kick water at you, but is unable to kick up a sufficient amount of water.",
        "A cockatrice screeches as {pronoun} stares hatefully at you."
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
