{
  schema_version: 3,
  name: "crystal crab",
  noun: "crab",
  url: "https://gswiki.play.net/crystal_crab",
  picture: "",
  level: 8,
  family: "Crab",
  type: "Crustacean",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 94,
  speed: nil,
  height: 1,
  size: "small",
  areas: [
    {
      name: "Thurfel's Island",
      uids: [7530006..7530029]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ensnare",
        as: (109..122)
      },
      {
        name: "Claw",
        as: (100..112)
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
    asg: "9N",
    immunities: [],
    melee: (38..81),
    ranged: (31..44),
    bolt: (31..44),
    udf: (66..99),
    bar_td: 24,
    cle_td: 24,
    emp_td: 24,
    pal_td: (21..24),
    ran_td: 24,
    sor_td: 24,
    wiz_td: nil,
    mje_td: 24,
    mne_td: 24,
    mjs_td: nil,
    mns_td: (18..24),
    mnm_td: 24,
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
    boxes: nil,
    skin: "a faceted crystal crab shell",
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The multi-faceted shell of this oversized crab resembles a massive oval gem. Underneath the protective covering are its formidable claws and pincers, the front pair easily the largest. The creature's eyestalks peer about nervously at even the slightest sound."
    ],
    arrival: [],
    flee: [
      "A glittering crystal crab retreats back into its shell.",
      "A glittering crystal crab twitches and skitters {direction}.",
      "A crystal crab retreats back into {pronoun} shell."
    ],
    death: [
      "The crystal crab collapses to the ground, clacks its pincers and dies.",
      "The crystal crab clacks its pincers a final agonizing time and dies."
    ],
    decay: [
      "A glittering crystal crab decays into compost."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A crystal crab twitches fiercely, shaking off the stun!"
    ],
    attacks: {
      bite: [
        "A crystal crab snaps {pronoun} pincers, while swaying erratically."
      ],
      attack: [
        "A crystal crab tries to ensnare you!"
      ],
      claw: [
        "A crystal crab claws at you!"
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
