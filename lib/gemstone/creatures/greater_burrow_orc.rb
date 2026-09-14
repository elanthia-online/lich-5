{
  schema_version: 3,
  name: "greater burrow orc",
  noun: "orc",
  url: "https://gswiki.play.net/greater_burrow_orc",
  picture: "",
  level: 8,
  family: "Orc",
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
  max_hp: 110,
  speed: 11,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Melgorehn's Valley",
      uids: [2148026..2148040]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Short sword",
        as: (118..128)
      },
      {
        name: "Unknown",
        as: 108
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
    asg: "8",
    immunities: [],
    melee: (49..121),
    ranged: (28..45),
    bolt: (28..45),
    udf: (61..129),
    bar_td: 24,
    cle_td: 24,
    emp_td: 24,
    pal_td: (21..24),
    ran_td: 24,
    sor_td: 24,
    wiz_td: nil,
    mje_td: 24,
    mne_td: 24,
    mjs_td: 24,
    mns_td: 24,
    mnm_td: 24,
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
    "a wooden shield",
    "some double leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an orc claw",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The burrow orc would stand roughly six feet high, were he not stooped over. He is thinner and more gaunt than the land-roaming orcs, with sickly white skin and no hair on his smelly frame. He seems more interested in stuffing himself and protecting his burrow than anything else."
    ],
    arrival: [],
    flee: [
      "A greater burrow orc rushes out of a burrow, bellowing a challenge!"
    ],
    death: [
      "A greater burrow orc growls one last time and dies.",
      "A greater burrow orc growls silently one last time and dies."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A greater burrow orc swings {weapon} at you!"
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
