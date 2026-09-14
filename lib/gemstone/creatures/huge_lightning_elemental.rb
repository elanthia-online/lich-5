{
  schema_version: 3,
  name: "huge lightning elemental",
  noun: "elemental",
  url: "https://gswiki.play.net/huge_lightning_elemental",
  picture: "",
  level: 100,
  family: "Elemental",
  type: "Elemental",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: false,
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
        name: "Charge",
        as: (460..495)
      },
      {
        name: "Powerful lightning bolt",
        as: 469
      }
    ],
    bolt_spells: [
      {
        name: "Major Shock (910)",
        as: 469
      },
      {
        name: "Cone of Elements (518)",
        as: 469
      }
    ],
    warding_spells: [
      {
        name: "Elemental Strike (415)",
        cs: 335
      },
      {
        name: "Mind Jolt (706)",
        cs: 322
      }
    ],
    offensive_spells: [
      {
        name: "Lightning mote"
      }
    ],
    maneuvers: [
      {
        name: "Lava glob"
      },
      {
        name: "Major Elemental Wave"
      },
      {
        name: "Burrow Ambush"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "10",
    immunities: [],
    melee: nil,
    ranged: (280..358),
    bolt: (280..358),
    udf: nil,
    bar_td: 406,
    cle_td: 431,
    emp_td: 431,
    pal_td: nil,
    ran_td: (362..372),
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 431,
    mns_td: 431,
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
    other: "essence of air",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The lightning elemental is a crackling mass of solidified power, definitely alien to Elanthia. Nearly gelatinous in substance, solid bolts of lightning weave themselves into the skeletal form of some horrible beast, only to arc in an instant to a vaguely humanoid form and then back again."
    ],
    arrival: [
      "A gust of wind and a flash of lightning herald the arrival of a stooped titan stormcaller as {pronoun} lumbers in."
    ],
    flee: [],
    death: [],
    decay: [
      "The siren's soft aura fades and her flesh crumbles to reveal the corpse of a hideous scaled creature, which then quickly decays away."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A huge lightning elemental charges at you, crackling with power!",
        "A huge lightning elemental releases sparks towards you!"
      ],
      hurl: [
        "A huge lightning elemental hurls {weapon} at you!"
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
