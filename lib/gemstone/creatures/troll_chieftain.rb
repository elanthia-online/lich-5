{
  schema_version: 3,
  name: "troll chieftain",
  noun: "chieftain",
  url: "https://gswiki.play.net/troll_chieftain",
  picture: "",
  level: 27,
  family: "Troll",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 300,
  speed: 8,
  height: 8,
  size: "large",
  areas: [
    {
      name: "Hidden Vale",
      uids: [40001..40013, 40020..40020]
    },
    {
      name: "unmapped",
      uids: [40014..40019]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Battle axe",
        as: (216..270)
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
    asg: "13",
    immunities: [],
    melee: (86..96),
    ranged: (79..114),
    bolt: (79..114),
    udf: nil,
    bar_td: nil,
    cle_td: 96,
    emp_td: 96,
    pal_td: (78..81),
    ran_td: 96,
    sor_td: 92,
    wiz_td: nil,
    mje_td: 88,
    mne_td: 88,
    mjs_td: 96,
    mns_td: 96,
    mnm_td: (81..88),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a battle axe",
    "a flail",
    "a leather helm",
    "a military pick",
    "a vine-wrapped rusting bastard sword",
    "a visored helm",
    "an augmented breastplate",
    "some brigandine armor",
    "some chain mail"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "troll fang",
    other: [
      "glimmering blue essence shard",
      "glimmering blue mote of essence",
      "t'ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Similar to most trolls, the grey muscular body of the troll chieftain displays immense strength from head to toe. It is different from its lesser-ranked brethren in two respects, however. First, there is a glimmer of intelligence in its small, close-set, pink eyes. Second, two long, inflamed scars run from its chest, down its forearms, to end at its elbows. These signify the testing the troll shamans have put the troll chieftain through to ensure it is qualified for its rank. It is rumored that no one ever again sees those that do not qualify."
    ],
    arrival: [
      "A troll chieftain just arrived!",
      "A troll chieftain just arrived."
    ],
    flee: [
      "A troll chieftain runs {direction}."
    ],
    death: [
      "The troll chieftain bellows in rage one last time and dies.",
      "The troll chieftain snarls {pronoun} defiance before collapsing and going still.",
      "The troll chieftain snarls {pronoun} defiance one last time before going still."
    ],
    decay: [
      "A troll chieftain decays into compost."
    ],
    search: [
      "A troll chieftain sniffs the air cautiously."
    ],
    spell_prep: [],
    attacks: {
      attack: [
        "A troll chieftain swings {weapon} at you!",
        "A troll chieftain charges towards you shouting, \"Ird nramugh mus ird!\"."
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
