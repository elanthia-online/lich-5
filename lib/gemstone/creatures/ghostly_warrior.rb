{
  schema_version: 3,
  name: "ghostly warrior",
  noun: "warrior",
  url: "https://gswiki.play.net/ghostly_warrior",
  picture: "",
  level: 18,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 212,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Wolves' Den",
      uids: [390002..390022, 390025..390048]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Broadsword",
        as: 173
      },
      {
        name: "Morning star",
        as: 168
      },
      {
        name: "Flail",
        as: 153
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
    asg: "various",
    immunities: [],
    melee: (90..152),
    ranged: (85..147),
    bolt: (85..147),
    udf: (127..170),
    bar_td: nil,
    cle_td: (48..60),
    emp_td: 54,
    pal_td: (51..60),
    ran_td: (51..60),
    sor_td: (51..54),
    wiz_td: nil,
    mje_td: (48..60),
    mne_td: (48..60),
    mjs_td: (54..57),
    mns_td: (54..57),
    mnm_td: (48..54),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "Dispel sanctuaries",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a broadsword",
    "a flail",
    "a morning star",
    "a reinforced shield",
    "some chain mail",
    "some cuirbouilli leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Alchemy (common)",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [],
    arrival: [],
    flee: [
      "A ghostly warrior creeps {direction}!"
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    stun_break: [
      "A ghostly warrior looses a keening howl, shaking off the stun!"
    ],
    attacks: {
      attack: [
        "A warrior swings {weapon} at you!",
        "A ghostly warrior swings a broadsword at you!",
        "A ghostly warrior swings a flail at you!"
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
