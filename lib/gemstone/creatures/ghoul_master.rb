{
  schema_version: 3,
  name: "ghoul master",
  noun: "master",
  url: "https://gswiki.play.net/ghoul_master",
  picture: "",
  level: 16,
  family: "Ghoul",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 145,
  speed: 8,
  height: 7,
  size: "large",
  areas: [
    {
      name: "The Graveyard",
      uids: [18029..18035, 18070..18070, 2162101..2162122]
    },
    {
      name: "Plains of Bone",
      uids: [14011023..14011035]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 137
      },
      {
        name: "Claw",
        as: 147
      },
      {
        name: "Pound (attack)",
        as: 137
      },
      {
        name: "Fist",
        as: 137
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Bite",
        cs: 88
      },
      {
        name: "Claw",
        cs: 88
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "14",
    immunities: [],
    melee: (41..151),
    ranged: (49..59),
    bolt: (49..59),
    udf: 211,
    bar_td: 48,
    cle_td: 48,
    emp_td: 48,
    pal_td: (45..48),
    ran_td: 48,
    sor_td: 48,
    wiz_td: nil,
    mje_td: 48,
    mne_td: 48,
    mjs_td: (48..60),
    mns_td: (48..60),
    mnm_td: 48,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a battered wooden shield",
    "a metal aventail",
    "a wooden shield",
    "some black double chain",
    "some double chain"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a ghoul finger",
    other: "s'ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Broader and taller then the more common ghouls, this one stands with some cold bearing of command and power. Tattered rags of velvet and silk still drape the corrupt form and a keen light of evil will and force dominates the ruined face now rotting and festered. The aura of its power tingles along your nerves and brings a cold sweat to your brow as you gaze into eyes, now vacant, which seem to stare back at you with cruel disdain.\n\nThe ghoul master is large in size and about seven feet high in its current state."
    ],
    arrival: [
      "A ghoul master just arrived.",
      "A ghoul master just arrived, limping."
    ],
    flee: [
      "A ghoul master runs {direction}."
    ],
    death: [
      "The ghoul master falls to the ground motionless.",
      "The ghoul master screams evilly one last time and goes still."
    ],
    decay: [
      "A ghoul master turns to dust."
    ],
    search: [],
    spell_prep: [
      "A ghoul master mutters a chant!",
      "A ghoul master gestures at {target}!"
    ],
    attacks: {
      attack: [
        "A ghoul master pounds at you with {pronoun} fist!",
        "A ghoul master pounds at {target} with {pronoun} fist!"
      ],
      bite: [
        "A ghoul master tries to bite you!"
      ],
      claw: [
        "A ghoul master claws at you!"
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
