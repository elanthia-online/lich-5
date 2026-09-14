{
  schema_version: 3,
  name: "dark shambler",
  noun: "shambler",
  url: "https://gswiki.play.net/dark_shambler",
  picture: "",
  level: 17,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 218,
  speed: 9,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Plains of Bone",
      uids: [14011023..14011035]
    },
    {
      name: "Vornavian Coast",
      uids: [4217201..4217216]
    },
    {
      name: "Upper Trollfang",
      uids: [16058..16064]
    },
    {
      name: "Abbey",
      uids: [4132101..4132118]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Two-handed sword",
        as: 175
      },
      {
        name: "Immense dark steel bidenhander",
        as: 165
      },
      {
        name: "Twohanded sword",
        as: 175
      },
      {
        name: "Broadsword",
        as: 175
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
    asg: "10",
    immunities: [],
    melee: (115..238),
    ranged: (41..140),
    bolt: (41..140),
    udf: (145..235),
    bar_td: 51,
    cle_td: 51,
    emp_td: 51,
    pal_td: (48..51),
    ran_td: 51,
    sor_td: 51,
    wiz_td: 51,
    mje_td: 51,
    mne_td: 51,
    mjs_td: (51..54),
    mns_td: (51..54),
    mnm_td: (49..51),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a blackened twohanded sword",
    "a broadsword",
    "a bruised left eye",
    "a bruised right eye",
    "a completely severed right arm",
    "a crude dark visored helm",
    "a suit of form-fitting night black brigandine",
    "a twohanded sword",
    "a visored helm",
    "a wooden shield",
    "an immense dark steel bidenhander",
    "some brigandine armor"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a glistening black eye",
    other: [
      "s'ayanad crystal",
      "ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Very little of the dark shambler is not thickly muscled. This squat humanoid lumbers through the countryside, surveying the world through glistening black eyes. Were it not for the eyes, the dark shambler could almost be taken for a shadow from a distance, for its skin is also entirely black. The eyes glisten eerily, though, while the rest of the dark shambler is a flat shade of charcoal that appears to absorb the light more than reflect it."
    ],
    arrival: [
      "A dark shambler just arrived!",
      "A dark shambler just arrived."
    ],
    flee: [
      "A dark shambler runs {direction}."
    ],
    death: [
      "The dark shambler falls to the ground motionless.",
      "The dark shambler screams evilly one last time and goes still.",
      "The dark shambler twitches violently, then dies."
    ],
    decay: [
      "A dark shambler turns to dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A dark shambler swings {weapon} at you!",
        "A dark shambler swings a twohanded sword at {target}!"
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
