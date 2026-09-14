{
  schema_version: 3,
  name: "deranged sentry",
  noun: "sentry",
  url: "https://gswiki.play.net/deranged_sentry",
  picture: "",
  level: 13,
  family: "Humanoid",
  type: "Biped",
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
  max_hp: 162,
  speed: 10,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "Thurfel's Island",
      uids: [7531026..7531042]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Halberd",
        as: 167
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Disarm Weapon"
      },
      {
        name: "Tackle"
      },
      {
        name: "Trip"
      },
      {
        name: "Halberd Sweep"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "11",
    immunities: [],
    melee: (97..196),
    ranged: (72..96),
    bolt: (72..96),
    udf: (113..224),
    bar_td: (39..42),
    cle_td: (33..42),
    emp_td: (39..47),
    pal_td: (30..39),
    ran_td: (39..45),
    sor_td: (33..45),
    wiz_td: nil,
    mje_td: (39..45),
    mne_td: (39..45),
    mjs_td: (36..45),
    mns_td: (36..45),
    mnm_td: (33..45),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a pair of unlaced boots",
    "a pearlescent abalone-hafted halberd",
    "some garish shell-studded leathers"
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
      "Garbed in bright crimson armor, the deranged sentry appears alert and ready for battle. The sentry is haphazardly dressed with unlaced boots, leathers and a helm that looks to be about three sizes to big."
    ],
    arrival: [
      "A deranged sentry lumbers in.",
      "A deranged sentry charges in, shouting a warning!"
    ],
    flee: [
      "A deranged sentry lumbers {direction}."
    ],
    death: [
      "The deranged sentry vainly tries to shout a warning, then goes still."
    ],
    decay: [
      "The deranged sentry decays into a grisly pile of armor, blood, and bone."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A deranged sentry holds {pronoun} head as {pronoun} tries to regain {pronoun} bearings."
    ],
    attacks: {
      attack: [
        "A deranged sentry swings {weapon} at you!",
        "A deranged sentry swings {pronoun} {weapon} at your vultite bastard sword!"
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
