{
  schema_version: 3,
  name: "blackened decaying tumbleweed",
  noun: "tumbleweed",
  url: "https://gswiki.play.net/blackened_decaying_tumbleweed",
  picture: "",
  level: 39,
  family: "Tumbleweed",
  type: "Plantlife",
  undead: true,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "corporeal undead"
  ],
  bcs: true,
  max_hp: 381,
  speed: 7,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Abandoned Farm",
      uids: [4124050..4124062]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Stinger (attack)"
      },
      {
        name: "Stinger",
        as: 252
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tumbleweed roll"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (105..309),
    ranged: (123..148),
    bolt: (123..148),
    udf: (149..349),
    bar_td: nil,
    cle_td: (138..147),
    emp_td: (138..147),
    pal_td: (108..117),
    ran_td: (111..117),
    sor_td: (130..160),
    wiz_td: nil,
    mje_td: 150,
    mne_td: (137..167),
    mjs_td: (183..192),
    mns_td: (123..153),
    mnm_td: (114..123),
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
    skin: "desiccated stem",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [],
    arrival: [
      "A blackened decaying tumbleweed spins in kicking up snow as it arrives!"
    ],
    flee: [
      "A blackened decaying tumbleweed rolls {direction}."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A blackened decaying tumbleweed stabs at you with {pronoun} stinger!",
        "A blackened decaying tumbleweed stabs at {target} with {pronoun} stinger!"
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
