{
  schema_version: 3,
  name: "gnoll guard",
  noun: "guard",
  url: "https://gswiki.play.net/gnoll_guard",
  picture: "",
  level: 17,
  family: "Gnoll",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: true,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 126,
  speed: nil,
  height: 3,
  size: "small",
  areas: [
    {
      name: "Foothills of Zeltoph",
      uids: [10009..10060, 11201..11221]
    }
  ],
  attack_attributes: {
    physical_attacks: [],
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
    melee: nil,
    ranged: (84..86),
    bolt: (84..86),
    udf: 223,
    bar_td: nil,
    cle_td: (48..51),
    emp_td: (32..51),
    pal_td: (48..54),
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: (51..57),
    mns_td: (51..57),
    mnm_td: 51,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: [
      "Hides when attacked"
    ]
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a broadsword",
    "a wooden shield",
    "some full leather"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The outfit this gnoll is dressed in couldn't exactly be called a uniform, but there is a badge pinned on the front, signifying him as a member of the guard. The faint scent of fermented mushrooms wafts from the guard."
    ],
    arrival: [
      "A gnoll guard marches in."
    ],
    flee: [],
    death: [
      "The gnoll guard rolls over and dies.",
      "The gnoll guard falls to the ground and dies."
    ],
    decay: [
      "A gnoll guard's remains dissolve into the ground."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A gnoll guard swings a broadsword at you!"
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
