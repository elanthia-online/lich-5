{
  schema_version: 3,
  name: "writhing icy bush",
  noun: "bush",
  url: "https://gswiki.play.net/writhing_icy_bush",
  picture: "",
  level: 36,
  family: "Bush",
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
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 362,
  speed: 7,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Abandoned Farm",
      uids: [4124037..4124049]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "small glistening thorn",
        as: 260
      },
      {
        name: "Stinger (attack)",
        as: 220
      },
      {
        name: "Thorn",
        as: 230
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "thorn fling"
      },
      {
        name: "Lash"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (120..284),
    ranged: (107..145),
    bolt: (107..145),
    udf: (168..215),
    bar_td: nil,
    cle_td: (125..131),
    emp_td: (117..135),
    pal_td: (105..111),
    ran_td: (102..108),
    sor_td: (117..147),
    wiz_td: nil,
    mje_td: 139,
    mne_td: (123..153),
    mjs_td: (165..171),
    mns_td: (111..141),
    mnm_td: (105..108),
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
    skin: "blood-stained leaf",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [],
    arrival: [
      "A writhing icy bush just arrived!",
      "A writhing icy bush hops in and plants {pronoun} roots."
    ],
    flee: [],
    death: [
      "A writhing icy bush collapses to the ground, shakes one last time and dies."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A writhing icy bush spits a thorn towards {target}!"
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
