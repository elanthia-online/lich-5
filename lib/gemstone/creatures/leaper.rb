{
  schema_version: 3,
  name: "leaper",
  noun: "leaper",
  url: "https://gswiki.play.net/leaper",
  picture: "",
  level: 6,
  family: "Leaper",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
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
      name: "Coastal Cliffs",
      uids: [67023..67033]
    },
    {
      name: "Southern Snowfields",
      uids: [4128031..4128040]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (84..94)
      },
      {
        name: "Claw",
        as: 94
      },
      {
        name: "Stomp",
        as: 94
      },
      {
        name: "Foot",
        as: 84
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
    melee: (12..29),
    ranged: 9,
    bolt: 9,
    udf: (63..80),
    bar_td: 18,
    cle_td: 18,
    emp_td: 18,
    pal_td: (15..18),
    ran_td: 18,
    sor_td: 18,
    wiz_td: nil,
    mje_td: 18,
    mne_td: 18,
    mjs_td: 18,
    mns_td: 18,
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
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "a leaper hide",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The leaper appears a bizarre cross between a wolf and a frog. Perhaps six feet from snout to rump, covered with slick, hairless skin in a dark green, it lacks all trace of fur but has a set of fangs worthy of any wolf that ever strode the land. Extra long front legs tipped with raking claws give it the bounding gait that has earned its name.\n\nThe leaper is medium in size and about three feet high."
    ],
    arrival: [],
    flee: [
      "A leaper bounds {direction}.",
      "A leaper lopes {direction}, bounding up and down with {pronoun} powerful front legs!",
      "A leaper growls as {pronoun} slowly backs away."
    ],
    death: [
      "The leaper collapses to the ground, emits a final snarl, and dies.",
      "The leaper twitches and dies.",
      "The leaper collapses to the ground, emits a final silent snarl, and dies."
    ],
    decay: [
      "A leaper decays into a pile of hair and bone."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A leaper staggers as {pronoun} tries to regain {pronoun} bearings!"
    ],
    attacks: {
      attack: [
        "A leaper stomps at you with {pronoun} foot!"
      ],
      bite: [
        "A leaper tries to bite you!"
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
