{
  schema_version: 3,
  name: "dark vortece",
  noun: "vortece",
  url: "https://gswiki.play.net/dark_vortece",
  picture: "",
  level: 42,
  family: "Vortece",
  type: "Globoid",
  undead: false,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: false,
  sympathy: false,
  muggable: false,
  sleepable: nil,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Magical",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: 7,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "The Broken Lands",
      uids: [94026..94040]
    }
  ],
  attack_attributes: {
    physical_attacks: [],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Unknown",
        cs: 224
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: ["magic"],
    melee: (24..141),
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 159,
    wiz_td: nil,
    mje_td: 158,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
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
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: nil,
    other: "essence of air",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The dark vortece is a mass of dark, swirling shadows. Little more is known about this deadly creature despite many attempts to study their origins. This is understandable when you consider the one well known fact about them: Simply being in the presense of a dark vortece is enough to endanger your life, due to their tendency to drain the life out of everything around them."
    ],
    arrival: [
      "A dark vortece drifts in smoothly, trailed by a shadowy haze."
    ],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A dark vortece shoots a shaft of pure darkness at you!"
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
