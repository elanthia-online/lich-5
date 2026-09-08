{
  schema_version: 3,
  name: "ebon swine",
  noun: "swine",
  url: "https://gswiki.play.net/ebon_swine",
  picture: "",
  level: nil,
  family: "Suine",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: nil,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 131,
  speed: 15,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Black Weald",
      uids: [7130001..7130018]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 158
      },
      {
        name: "Charge",
        as: 181
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
    asg: nil,
    immunities: [],
    melee: 67,
    ranged: 67,
    bolt: 67,
    udf: (87..140),
    bar_td: nil,
    cle_td: (39..48),
    emp_td: (21..51),
    pal_td: (36..45),
    ran_td: (42..48),
    sor_td: (36..45),
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: (36..48),
    mns_td: (36..48),
    mnm_td: 42,
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
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      ""
    ],
    arrival: [
      "An ebon swine crashes into view!",
      "An ebon swine trots in!"
    ],
    flee: [
      "An ebon swine trots {direction}.",
      "An ebon swine grunts as {pronoun} slowly backs away."
    ],
    death: [
      "The ebon swine lets out a final agonized squeal and dies.",
      "The ebon swine collapses to the ground, emits a final squeal, and dies.",
      "The ebon swine twitches violently, then dies.",
      "The ebon swine silently lets out a final agonized squeal and dies."
    ],
    decay: [
      "An ebon swine decays into a pile of fur and bone."
    ],
    search: [
      "An ebon swine sniffs the air anxiously.",
      "An ebon swine glances around, sure that {pronoun} has missed something..."
    ],
    spell_prep: [],
    attacks: {
      attack: [
        "An ebon swine charges at you!"
      ],
      bite: [
        "An ebon swine tries to bite you!"
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
