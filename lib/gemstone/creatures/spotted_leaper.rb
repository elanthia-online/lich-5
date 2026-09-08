{
  schema_version: 3,
  name: "spotted leaper",
  noun: "leaper",
  url: "https://gswiki.play.net/spotted_leaper",
  picture: "",
  level: 4,
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
  max_hp: 51,
  speed: 10,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Rambling Meadows",
      uids: [14006021..14006040]
    },
    {
      name: "Noralgar Forest",
      uids: [4286004..4286012]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (68..76)
      },
      {
        name: "Claw",
        as: 76
      },
      {
        name: "Stomp",
        as: 76
      },
      {
        name: "Unknown",
        as: 76
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
    melee: (9..33),
    ranged: (7..17),
    bolt: (7..17),
    udf: (56..76),
    bar_td: 12,
    cle_td: 12,
    emp_td: 12,
    pal_td: (9..12),
    ran_td: 12,
    sor_td: 12,
    wiz_td: 12,
    mje_td: 12,
    mne_td: 12,
    mjs_td: 12,
    mns_td: 12,
    mnm_td: 12,
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
    skin: "a spotted leaper pelt",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The spotted leaper appears a bizarre cross between a wolf and a frog. Perhaps six feet from snout to rump, covered with slick, hairless skin that is a dark green color with occasional pink splotches, it lacks all trace of fur but has a set of fangs worthy of any wolf that ever strode the land. Extra long front legs tipped with raking claws give it the bounding gait that has earned it its name."
    ],
    arrival: [],
    flee: [
      "A spotted leaper bounds {direction}.",
      "A spotted leaper growls as {pronoun} slowly backs away."
    ],
    death: [
      "The spotted leaper collapses to the ground, emits a final snarl, and dies.",
      "The spotted leaper twitches and dies.",
      "The spotted leaper collapses to the ground, emits a final silent snarl, and dies."
    ],
    decay: [
      "A spotted leaper decays into a pile of hair and bone."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A spotted leaper staggers as {pronoun} tries to regain {pronoun} bearings!"
    ],
    attacks: {
      bite: [
        "A spotted leaper tries to bite you!"
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
