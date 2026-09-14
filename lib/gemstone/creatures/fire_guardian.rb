{
  schema_version: 3,
  name: "fire guardian",
  noun: "guardian",
  url: "https://gswiki.play.net/fire_guardian",
  picture: "",
  level: 16,
  family: "Elemental",
  type: "Biped",
  undead: false,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: false,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Element-based"
  ],
  bcs: true,
  max_hp: 141,
  speed: 16,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Glatoph",
      uids: [35010..35024]
    },
    {
      name: "Vornavian Coast",
      uids: [4202301..4202320]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: (122..152)
      },
      {
        name: "Ensnare (attack)",
        as: 152
      },
      {
        name: "Charge (attack)",
        as: 152
      }
    ],
    bolt_spells: [
      {
        name: "Minor Fire (906)",
        as: 124
      },
      {
        name: "Major Fire (908)",
        as: 124
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "7N",
    immunities: [],
    melee: (37..51),
    ranged: (27..37),
    bolt: (27..37),
    udf: (60..67),
    bar_td: nil,
    cle_td: 48,
    emp_td: 48,
    pal_td: (45..48),
    ran_td: 48,
    sor_td: 48,
    wiz_td: nil,
    mje_td: 48,
    mne_td: 48,
    mjs_td: 48,
    mns_td: 48,
    mnm_td: 48,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Essence of fire",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A towering mass of flame and smoke formed into a caricature of a living being, the fire guardian is awesome to behold. The fumes of endless burning and the fierce heat serve this foul thing as well as any armor made by mortal; and the power of its flame has fused even the finest vultite shields to the hands of their wearers and turned mighty swords into dripping stubs of molten alloy."
    ],
    arrival: [],
    flee: [],
    death: [
      "The fire guardian falls to the ground motionless.",
      "The fire guardian screams evilly one last time and goes still."
    ],
    decay: [
      "A fire guardian turns to dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A fire guardian gestures at you!",
        "A fire guardian swings {weapon} at you!"
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
