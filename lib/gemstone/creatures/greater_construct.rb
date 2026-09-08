{
  schema_version: 3,
  name: "greater construct",
  noun: "construct",
  url: "https://gswiki.play.net/greater_construct",
  picture: "",
  level: 96,
  family: "Golem",
  type: "Biped",
  undead: false,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: false,
  sympathy: false,
  muggable: true,
  sleepable: false,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Magical",
    "Boss"
  ],
  bcs: true,
  max_hp: 517,
  speed: 9,
  height: 18,
  size: "huge",
  areas: [
    {
      name: "Old Ta'Faendryl",
      uids: [17004001..17004028, 17004030..17004120]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Stomp"
      },
      {
        name: "Arm",
        as: (449..460)
      },
      {
        name: "Smash",
        as: (459..468)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Crush"
      },
      {
        name: "Tandem Dispel"
      },
      {
        name: "Team Swat"
      },
      {
        name: "Ground Slam"
      },
      {
        name: "Slam"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "20N",
    immunities: ["magic"],
    melee: (219..499),
    ranged: (192..387),
    bolt: (192..387),
    udf: (456..487),
    bar_td: nil,
    cle_td: (366..387),
    emp_td: (358..379),
    pal_td: nil,
    ran_td: 326,
    sor_td: 398,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: [
      "Antimagic aura"
    ]
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a polished steel shield"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "crystal core",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    attacks: {
      attack: [
        "A glorious greater construct raises {pronoun} massive foot and attempts to smash you!",
        "A greater construct raises {pronoun} massive foot and attempts to smash you!",
        "A greater construct swings {weapon} at you!",
        "A greater construct slams towards you, but you evade the attack!"
      ]
    },
    stand: [
      "A greater construct rises slowly until {pronoun} towers overhead once more."
    ],
    description: [
      "The white granite-like features of the greater construct hold no hints of the giant creature's intentions or motivations. Its alabaster skin made more of the hardest rock than any living tissue makes the construct a formidable opponent for any who dare to trifle with it. Massing more than ten giantmen, it is a mountain of rock when in motion and very little, man or animal can oppose its desired path of travel once it is in motion."
    ],
    arrival: [
      "A greater construct stomps in.",
      "A glorious greater construct stomps in.",
      "A hoarse rumbling heralds the arrival of a greater construct!",
      "A deep humming sound comes from a greater construct as it lumbers in."
    ],
    flee: [
      "A greater construct stomps {direction}."
    ],
    death: [],
    decay: [
      "A greater construct's body crumbles until only a pile of rubble marks its remains."
    ],
    search: [],
    spell_prep: [],
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
