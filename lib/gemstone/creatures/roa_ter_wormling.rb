{
  schema_version: 3,
  name: "roa'ter wormling",
  noun: "wormling",
  url: "https://gswiki.play.net/roa'ter_wormling",
  picture: "",
  level: 24,
  family: "Worm",
  type: "Worm",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 212,
  speed: 7,
  height: 2,
  size: "medium",
  areas: [
    {
      name: "Zaerthu Tunnels",
      uids: [13009001..13009040]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge (attack)",
        as: 197
      },
      {
        name: "Charge",
        as: (191..197)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Burrow"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (129..273),
    ranged: (130..179),
    bolt: (130..179),
    udf: (98..267),
    bar_td: 78,
    cle_td: (68..77),
    emp_td: (73..82),
    pal_td: (66..72),
    ran_td: (72..78),
    sor_td: (76..82),
    wiz_td: nil,
    mje_td: (75..82),
    mne_td: (75..82),
    mjs_td: (73..76),
    mns_td: (73..76),
    mnm_td: (72..78),
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
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The roa'ter wormling is large worm that seems not quite fully grown, and yet it is still a massive creature around fifteen feet long. Though young, it possesses great strength and moves quickly about. Light red in color, it seems to have no eyes, but its keen tremor sense quickly finds targets."
    ],
    arrival: [],
    flee: [
      "A roa'ter wormling slithers {direction}.",
      "A flashy roa'ter wormling slithers {direction}.",
      "A dazzling roa'ter wormling slithers {direction}.",
      "The roa'ter wormling warily backs away."
    ],
    death: [
      "The wormling rolls over and dies."
    ],
    decay: [
      "A roa'ter wormling decays into compost.",
      "A combative roa'ter wormling decays into compost.",
      "A belligerent roa'ter wormling decays into compost.",
      "A dazzling roa'ter wormling decays into compost.",
      "A flashy roa'ter wormling decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A roa'ter wormling charges at you!"
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
