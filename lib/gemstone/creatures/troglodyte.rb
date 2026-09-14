{
  schema_version: 3,
  name: "troglodyte",
  noun: "troglodyte",
  url: "https://gswiki.play.net/troglodyte",
  picture: "",
  level: 3,
  family: "Humanoid",
  type: "Biped",
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
  max_hp: 60,
  speed: 15,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Upper Dragonsclaw",
      uids: [2121015..2121024]
    },
    {
      name: "Rocky Shoals",
      uids: [7127020..7127030]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Cudgel",
        as: 68
      },
      {
        name: "Unknown",
        as: 68
      },
      {
        name: "Closed fist",
        as: 46
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
    asg: "5",
    immunities: [],
    melee: (16..32),
    ranged: 13,
    bolt: (11..13),
    udf: 45,
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
  equipment: [
    "a cudgel",
    "a wooden shield",
    "some light leather"
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
      "Short and massively squat, the troglodyte resembles a clay figure of a human left in the hot sun until it settled into an untidy lump, misshapen and unlovely. Dressed in the crudest of untanned hides, the creature glares out at you with brutish cunning and hate from narrow eyes set deep beneath a heavily boned forehead. Massive arms and ragged claws caked with dirt twitch reflexively, ready to dig in the earth or to tear the throat out of anything it can catch and eat."
    ],
    arrival: [
      "A troglodyte just arrived."
    ],
    flee: [
      "A troglodyte heads {direction}.",
      "A troglodyte limps {direction}."
    ],
    death: [
      "The troglodyte falls to the ground and dies.",
      "The troglodyte screams one last time and dies."
    ],
    decay: [
      "A troglodyte decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A troglodyte swings {weapon} at you!"
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
