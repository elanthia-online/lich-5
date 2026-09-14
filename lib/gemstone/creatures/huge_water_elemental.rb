{
  schema_version: 3,
  name: "huge water elemental",
  noun: "elemental",
  url: "https://gswiki.play.net/huge_water_elemental",
  picture: "",
  level: 95,
  family: "Elemental",
  type: "Elemental",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: nil,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Extraplanar",
    "Magical"
  ],
  bcs: true,
  max_hp: 300,
  speed: 8,
  height: nil,
  size: "",
  areas: [
    {
      name: "Elemental Confluence",
      uids: [580001..580025, 581001..581025, 582001..582025, 583001..583025, 584001..584025, 585001..585025, 586001..586025, 587001..587025, 588001..588025]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound",
        as: 450
      }
    ],
    bolt_spells: [
      {
        name: "Minor Water (903)",
        as: 452
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Mystic Impedance (1708)"
      }
    ],
    maneuvers: [
      {
        name: "Water blast"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "10",
    immunities: [],
    melee: nil,
    ranged: (292..361),
    bolt: (292..361),
    udf: nil,
    bar_td: 370,
    cle_td: 400,
    emp_td: 400,
    pal_td: nil,
    ran_td: (344..354),
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 400,
    mns_td: 400,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Barrier",
      "Elemental Bias",
      "Elemental Defense I",
      "Elemental Defense II",
      "Elemental Defense III",
      "Elemental Targeting"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: nil,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: nil,
    other: "essence of water",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The water elemental's upper body is that of a humanoid, while its lower body forms a turbulent, watery vortex. The facial features of the elemental creature are vague and shifting, rippling with every contortion of its face. Sloshing and splashing noises accompany each movement of the water elemental, along with an odd gurgling."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [
      "A huge water elemental utters an incantation in an unfamiliar, bubbling language."
    ],
    attacks: {
      attack: [
        "A huge water elemental pounds at you with a churning aquatic fist!",
        "A huge water elemental forms {pronoun} hands, palms outward toward you!"
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
