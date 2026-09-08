{
  schema_version: 3,
  name: "thyril",
  noun: "thyril",
  url: "https://gswiki.play.net/thyril",
  picture: "",
  level: 2,
  family: "Thyril",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 51,
  speed: 15,
  height: 2,
  size: "small",
  areas: [
    {
      name: "Rambling Meadows",
      uids: [14006001..14006020]
    },
    {
      name: "Catacombs",
      uids: [490003..490005, 490008..490009, 490014..490015, 4126004..4126023]
    },
    {
      name: "Frozen Garden",
      uids: [4160002..4160020]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 42
      },
      {
        name: "Scimitar",
        as: 52
      },
      {
        name: "Unknown",
        as: 52
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
    asg: "1N",
    immunities: [],
    melee: (29..49),
    ranged: 1,
    bolt: 1,
    udf: (26..44),
    bar_td: 6,
    cle_td: 6,
    emp_td: 6,
    pal_td: (3..6),
    ran_td: 6,
    sor_td: 6,
    wiz_td: nil,
    mje_td: 6,
    mne_td: 6,
    mjs_td: 6,
    mns_td: 6,
    mnm_td: 6,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a leather helm",
    "a scimitar",
    "a wooden shield",
    "some full leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Alchemy (common)",
      "ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "This soldier of the small mammal legions resembles an overgrown mole, except that it stands upright. Intelligence is apparent in its bulbous, yellow eyes, and its clawed feet give it exceptional agility in moist areas. The skin of the thyril is a muddy, mottled mass of light brown and dark brown hair, allowing it to blend in well with the decayed vegetation and soil in underground lairs and other dank locales."
    ],
    arrival: [
      "A thyril just arrived.",
      "A thyril just arrived, limping."
    ],
    flee: [
      "A thyril heads {direction}.",
      "A thyril limps {direction}."
    ],
    death: [
      "The thyril falls to the ground and dies.",
      "The thyril screams one last time and dies."
    ],
    decay: [
      "A thyril decays into compost.",
      "A small, green cloud of smelly gas rises from the body of a big ugly kobold as he decays into compost."
    ],
    search: [],
    spell_prep: [],
    stand: [
      "A thyril stands back up with a grunt."
    ],
    attacks: {
      attack: [
        "A thyril swings {weapon} at you!"
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
