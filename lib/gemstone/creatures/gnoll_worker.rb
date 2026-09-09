{
  schema_version: 3,
  name: "gnoll worker",
  noun: "worker",
  url: "https://gswiki.play.net/gnoll_worker",
  picture: "",
  level: 10,
  family: "Gnoll",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: true,
  limbs: nil,
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
  max_hp: 130,
  speed: 7,
  height: 3,
  size: "small",
  areas: [
    {
      name: "Foothills of Zeltoph",
      uids: [10001..10009, 10021..10039, 11001..11014]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Hatchet",
        as: (112..125)
      },
      {
        name: "Unknown",
        as: 125
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
    asg: "6",
    immunities: [],
    melee: (124..159),
    ranged: (42..95),
    bolt: (42..95),
    udf: (83..158),
    bar_td: nil,
    cle_td: 30,
    emp_td: 30,
    pal_td: (27..30),
    ran_td: 30,
    sor_td: 30,
    wiz_td: nil,
    mje_td: 30,
    mne_td: 30,
    mjs_td: 30,
    mns_td: 30,
    mnm_td: 30,
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
    "a bruised left eye",
    "a bruised right eye",
    "a hatchet",
    "a wooden shield",
    "some working leathers"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The gnoll worker is about three feet tall and vaguely man-like. Gnolls in general have a dwarven or gnomish appearance, but are markedly different in a way that can't quite be pin-pointed. This particular gnoll is part of the working class with well-muscled arms and callused hands. There is little doubt that the gnoll would be a formidable opponent if the need should arise, or if backed into a corner."
    ],
    arrival: [
      "A gnoll worker strides in solemnly.",
      "A gnoll worker wanders in, sniffing the air.",
      "A gnoll worker strolls in.",
      "A gnoll worker rushes in, waving {pronoun} arms wildly."
    ],
    flee: [
      "A gnoll worker ambles {direction}."
    ],
    death: [
      "The gnoll worker falls to the ground and dies.",
      "The gnoll worker rolls over and dies."
    ],
    decay: [
      "A gnoll worker's remains dissolve into the ground."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A gnoll worker swings {weapon} at you!"
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
