{
  schema_version: 3,
  name: "ghost",
  noun: "ghost",
  url: "https://gswiki.play.net/ghost",
  picture: "",
  level: 2,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 51,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Coastal Cliffs",
      uids: [67043..67053]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Short sword",
        as: 58
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
    melee: (-13..-2),
    ranged: (-23..-13),
    bolt: (-23..-13),
    udf: 48,
    bar_td: 6,
    cle_td: 6,
    emp_td: 6,
    pal_td: 6,
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
    "a short sword",
    "a wooden shield"
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
      "Found near graveyards and other resting places of the dead, the ghost presents itself as a pale reflection of what it once was, a living, breathing person. Eyes long rotted away, appendages barely discernable, it knows not why it fights, but attacks the living at every occasion. The ghost fights relentlessly, knowing no fear, until victorious or utterly destroyed. Its agonized, horrific moans often chill those who face it."
    ],
    arrival: [
      "Out of thin air, a shadowy figure takes shape before your eyes and materializes into a ghost!",
      "A ghost just arrived."
    ],
    flee: [],
    death: [
      "The ghost slowly settles to the ground and begins to dissipate."
    ],
    decay: [
      "A ghost vanishes into thin air, leaving no trace behind."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A ghost swings {weapon} at you!"
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
