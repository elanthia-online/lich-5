{
  schema_version: 3,
  name: "huge lava elemental",
  noun: "elemental",
  url: "https://gswiki.play.net/huge_lava_elemental",
  picture: "",
  level: 100,
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
  speed: 7,
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
        name: "Pound (double attack)",
        as: 450
      },
      {
        name: "Molten fist",
        as: (409..496)
      },
      {
        name: "Roaring ball of fire",
        as: 469
      }
    ],
    bolt_spells: [
      {
        name: "Major Fire (908)",
        as: 469
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Lava glob"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "10",
    immunities: [],
    melee: nil,
    ranged: (285..361),
    bolt: (285..361),
    udf: nil,
    bar_td: 406,
    cle_td: 428,
    emp_td: 428,
    pal_td: nil,
    ran_td: (352..387),
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
    other: "essence of fire",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The lava elemental is a bubbling mound of lava, across which an occasional warped face appears before dissolving away. Various appendages form and melt away constantly, as the alien creature goes about its business."
    ],
    arrival: [],
    flee: [
      "A huge lava elemental flows {direction}, scorching the ground in {pronoun} wake.",
      "A huge lava elemental flows {direction}, leaving the ground scorched in {pronoun} wake!"
    ],
    death: [],
    decay: [
      "The lava elemental hardens into a chalky rock that quickly crumbles away into nothingness."
    ],
    search: [],
    spell_prep: [
      "A huge lava elemental's eyes glow brilliantly orange as {pronoun} opens {pronoun} mouth and spits forth a blazing ball of fire!",
      "A huge lava elemental glows with wild elemental energy as {pronoun} shrugs off the force controlling {pronoun}!"
    ],
    attacks: {
      attack: [
        "A huge lava elemental pounds at you with a molten fist!"
      ],
      hurl: [
        "A huge lava elemental hurls {weapon} at you!"
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
