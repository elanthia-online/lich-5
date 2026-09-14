{
  schema_version: 3,
  name: "dark vysan",
  noun: "vysan",
  url: "https://gswiki.play.net/dark_vysan",
  picture: "",
  level: 3,
  family: "Vysan",
  type: "Biped",
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
  max_hp: 62,
  speed: 12,
  height: 4,
  size: "small",
  areas: [
    {
      name: "Coastal Cliffs",
      uids: [68006..68008, 68030..68032, 4381001..4381021]
    },
    {
      name: "Glaise Cnoc Cemetery",
      uids: [14008025..14008051]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ensnare",
        as: 54
      },
      {
        name: "Pound",
        as: 44
      },
      {
        name: "Charge (attack)",
        as: 54
      },
      {
        name: "Fist",
        as: 44
      },
      {
        name: "Unknown",
        as: 44
      },
      {
        name: "Charge",
        as: 54
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
    melee: 22,
    ranged: 17,
    bolt: 17,
    udf: 50,
    bar_td: 9,
    cle_td: 9,
    emp_td: 9,
    pal_td: (6..9),
    ran_td: 9,
    sor_td: 9,
    wiz_td: 9,
    mje_td: 9,
    mne_td: 9,
    mjs_td: (6..9),
    mns_td: (6..9),
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
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The dark vysan is a peculiar beast, dapple gray and extremely bloated with gas to the point that it can float from place to place. Its appendages extend straight out from its rotund body, and its head resembles an overturned kettle. Afraid of bright light, it prefers to inhabit underground passageways, moving slowly from room to room in search of food and treasure."
    ],
    arrival: [],
    flee: [],
    death: [
      "The dark vysan falls to the ground motionless.",
      "The dark vysan screams evilly one last time and goes still."
    ],
    decay: [
      "The siren's soft aura fades and her flesh crumbles to reveal the corpse of a hideous scaled creature, which then quickly decays away."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A dark vysan pounds at you with {pronoun} fist!",
        "A dark vysan tries to ensnare you!",
        "A dark vysan charges at you!"
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
