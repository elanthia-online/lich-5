{
  schema_version: 3,
  name: "brown spinner",
  noun: "spinner",
  url: "https://gswiki.play.net/brown_spinner",
  picture: "",
  level: 9,
  family: "Arachnid",
  type: "Arachnid",
  undead: false,
  blood: true,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: false,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 90,
  speed: 8,
  height: 2,
  size: "medium",
  areas: [
    {
      name: "The Citadel",
      uids: [2102022..2102049]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw"
      },
      {
        name: "Pincer (attack)"
      },
      {
        name: "Pincer",
        as: 107
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Web"
      }
    ],
    special_abilities: [
      {
        name: "Web"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (79..168),
    ranged: (60..108),
    bolt: 60,
    udf: (93..160),
    bar_td: nil,
    cle_td: 27,
    emp_td: 27,
    pal_td: (24..27),
    ran_td: 27,
    sor_td: 27,
    wiz_td: nil,
    mje_td: 27,
    mne_td: 27,
    mjs_td: 27,
    mns_td: 27,
    mnm_td: 27,
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
    boxes: false,
    skin: "brown spinner leg",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "This servant of the huntress is both guardian and warrior for its mistress. Its brown coloring and smaller size makes it seem less dangerous than other, larger spiders. However, the fine brown hair on its body is probably used to seek out hidden spies, and its spinnaret to immobilize them."
    ],
    arrival: [],
    flee: [
      "A brown spinner scurries {direction}."
    ],
    death: [
      "The brown spinner's body jerks one last time and dies.",
      "The brown spinner collapses to the ground and dies."
    ],
    decay: [
      "A brown spinner's legs shrivel up beneath it as it decays into dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A brown spinner snaps at you with {pronoun} pincer!"
      ],
      bite: [
        "A brown spinner snaps at you with {pronoun} pincer!",
        "A brown spinner snaps at {target} with {pronoun} pincer!"
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
