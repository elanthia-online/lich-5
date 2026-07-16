{
  schema_version: 3,
  name: "triton magus",
  noun: "",
  url: "https://gswiki.play.net/triton_magus",
  picture: "",
  level: 102,
  family: "Triton",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: nil,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Ruined Temple",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Arrow",
        as: 431
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Nature's Fury (635)",
        cs: 433
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Targeting (425)"
      }
    ],
    maneuvers: [
      {
        name: "Feint"
      },
      {
        name: "Spike Thorn (616)"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8",
    immunities: [],
    melee: (345..443),
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 373,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I",
      "Elemental Defense II",
      "Elemental Defense III",
      "Natural Colors",
      "Resist Elements",
      "Self Control",
      "Sneaking",
      "Spirit Defense"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an iridescent triton hide",
    other: "a bundle of arrows"
  },
  messaging: {
    description: [
      "Moving quietly on wide, webbed feet, the triton magus seems to slip between the shadows, her damp mottled flesh shifting colors with the surroundings. The creature pauses frequently, her flared nostrils quivering as if seeking beings as nearly invisible as herself. A long row of tiny needle-sharp teeth protrudes from grey gums, visible behind her curled, wet lips. A loose robe in varying shades of grey and green covers the magus, hanging just below her twitching tail."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
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
