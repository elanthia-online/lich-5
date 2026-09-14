{
  schema_version: 3,
  name: "tegursh sentry",
  noun: "sentry",
  url: "https://gswiki.play.net/tegursh_sentry",
  picture: "",
  level: 30,
  family: "Tegursh",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
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
  max_hp: 350,
  speed: nil,
  height: 7,
  size: "large",
  areas: [
    {
      name: "Sorcerer's Isle",
      uids: [14202001..14202023]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Falchion",
        as: 207
      },
      {
        name: "Jeddart-axe",
        as: (176..225)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Shield Charge"
      },
      {
        name: "Tail Swipe"
      },
      {
        name: "Charge"
      }
    ],
    special_abilities: [
      {
        name: "Tail sweep"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (190..326),
    ranged: (113..225),
    bolt: (113..225),
    udf: (198..336),
    bar_td: 96,
    cle_td: (103..115),
    emp_td: (111..119),
    pal_td: (87..96),
    ran_td: (93..96),
    sor_td: (109..118),
    wiz_td: nil,
    mje_td: (120..123),
    mne_td: (120..123),
    mjs_td: (108..117),
    mns_td: (108..117),
    mnm_td: (87..96),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a belt pack",
    "a bruised left eye",
    "a bruised right eye",
    "a completely severed left arm",
    "a pitted iron falchion",
    "a pitted iron jeddart-axe",
    "a spiraled ram's horn",
    "a wood buckler"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a tegursh claw",
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Taller than a common human and of substantially heavier build, the tegursh sentry is a solid mass of bone and gristle overlaid with bony plates that cover most of his torso, legs, and arms. Beady, black eyes rimmed in red peer out from a twisted, deformed face, clearly orcish but with an elongated snout. The sentry's arms are as thick as tree branches, ending in three incredibly sharp claws. Unlike any orc you have seen, this creature has an armored tail tipped with pointy spikes."
    ],
    arrival: [],
    flee: [
      "A tegursh sentry backs away, the expression on {pronoun} scaly face a mixture of fear and loathing."
    ],
    death: [
      "A tegursh sentry rasps a final scream and dies.",
      "A tegursh sentry silently rasps a final scream and dies."
    ],
    decay: [],
    search: [
      "A tegursh sentry scans the area for any signs of intruders."
    ],
    spell_prep: [],
    attacks: {
      attack: [
        "A tegursh sentry swings {weapon} at you!",
        "A tegursh sentry lashes {pronoun} tail with lightning speed at your legs!"
      ],
      hurl: [
        "A tegursh sentry throws {weapon} at you!"
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
