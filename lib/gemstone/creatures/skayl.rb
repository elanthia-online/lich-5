{
  schema_version: 3,
  name: "skayl",
  noun: "skayl",
  url: "https://gswiki.play.net/skayl",
  picture: "",
  level: 54,
  family: "Elemental",
  type: "Globoid",
  undead: false,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: false,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Element-based",
    "Magical",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Volcano",
      uids: [3050023..3050036]
    },
    {
      name: "Eye of V'Tull",
      uids: [3060002..3060018]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: (257..328)
      },
      {
        name: "Ensnare (attack)",
        as: 328
      },
      {
        name: "Ensnare",
        as: (257..302)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Earthen Fury (917)"
      },
      {
        name: "Burrow Ambush",
        cs: 265
      },
      {
        name: "Ensnare",
        cs: 253
      }
    ],
    maneuvers: [
      {
        name: "Fire Wave"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16N",
    immunities: [],
    melee: (418..469),
    ranged: (109..198),
    bolt: (109..198),
    udf: 312,
    bar_td: 197,
    cle_td: (201..211),
    emp_td: (191..200),
    pal_td: (168..174),
    ran_td: (165..171),
    sor_td: (212..221),
    wiz_td: nil,
    mje_td: (224..235),
    mne_td: (224..235),
    mjs_td: (194..208),
    mns_td: (194..208),
    mnm_td: (172..175),
    defensive_spells: [
      "Elemental Bias (508)",
      "Strength (509)",
      "Mass Blur (911)"
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
    gems: nil,
    boxes: nil,
    skin: nil,
    other: [
      "a heart of smooth black glaes (cursed)",
      "essence of fire"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Flame suddenly hisses and spits from thin air, which shimmers in the resulting smoke like reflective crystal. Then abruptly, the air roils and begins to take on form. In mere heartbeats, it becomes obvious that the transparent bubble of conflagration is a sentient being. The skayl opens its gaping maw of fire and bellows a malign growl that is more felt than heard. In the next instant, the skayl melts down then reforms a short distance away, leaving a drift of smoke in its wake like a fraying shadow."
    ],
    arrival: [
      "A skayl rises from a pool of steaming liquid glaes!",
      "A skayl rises from a pool of steaming liquid glaes rumbling in pain!"
    ],
    flee: [],
    death: [
      "The skayl goes limp and it falls over as the fire slowly fades from its eyes."
    ],
    decay: [
      "Bright orange lava oozes out of the skayl before it crumbles into a lifeless pile of glaes."
    ],
    search: [],
    spell_prep: [],
    stand: [
      "A skayl melts into a pool of molten glaes and quickly reforms {reflexive} into a standing position."
    ],
    attacks: {
      attack: [
        "A skayl swings {weapon} at you!",
        "A skayl tries to ensnare you!",
        "A skayl releases a wave of fiery red energy at you!"
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
