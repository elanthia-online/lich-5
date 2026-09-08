{
  schema_version: 3,
  name: "huge steam elemental",
  noun: "elemental",
  url: "https://gswiki.play.net/huge_steam_elemental",
  picture: "",
  level: 99,
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
  speed: nil,
  height: 15,
  size: "huge",
  areas: [
    {
      name: "Elemental Confluence",
      uids: [580026..580053, 581026..581053, 582026..582053, 583026..583053, 584026..584053, 585026..585053, 586026..586053, 587026..587053, 588026..588053]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ensnare",
        as: 460
      },
      {
        name: "Boiling tendril",
        as: (469..491)
      }
    ],
    bolt_spells: [
      {
        name: "Minor Steam",
        as: 454
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Earthen Fury (917)"
      }
    ],
    maneuvers: [
      {
        name: "Major Elemental Wave"
      },
      {
        name: "Ethereal Wave"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "10",
    immunities: [],
    melee: nil,
    ranged: (263..337),
    bolt: (263..337),
    udf: nil,
    bar_td: 403,
    cle_td: 428,
    emp_td: 428,
    pal_td: nil,
    ran_td: (359..365),
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 428,
    mns_td: 428,
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
      "The steam elemental is a dense cloud of solid steam, occasionally manifesting a mouth or tendrils with which to affect its surroundings. It constantly expands and contracts, but never loses its unbearably hot aura."
    ],
    arrival: [],
    flee: [],
    death: [
      "The steam elemental dissipates into a warm breeze that fades rapidly away."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A huge steam elemental lashes out at you with a boiling tendril!",
        "A huge steam elemental releases a wave of heat at you!"
      ],
      bolt: [
        "A huge steam elemental hurls a seething blast of steam at you!"
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
