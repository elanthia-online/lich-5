{
  schema_version: 3,
  name: "naisirc",
  noun: "naisirc",
  url: "https://gswiki.play.net/naisirc",
  picture: "",
  level: 75,
  family: "Ghost",
  type: "Hybrid",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: 5,
  size: "large",
  areas: [
    {
      name: "The Rift",
      uids: [4566001..4566055]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge (attack)",
        as: 400
      },
      {
        name: "Ensnare (attack)",
        as: 396
      },
      {
        name: "Charge",
        as: 374
      },
      {
        name: "Ensnare",
        as: (366..370)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Call Wind (912)"
      },
      {
        name: "Tangleweed (610)"
      }
    ],
    maneuvers: [
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
    melee: (261..550),
    ranged: (221..373),
    bolt: (221..373),
    udf: (416..693),
    bar_td: (274..280),
    cle_td: (301..307),
    emp_td: (293..308),
    pal_td: (258..267),
    ran_td: (258..264),
    sor_td: (315..327),
    wiz_td: nil,
    mje_td: (330..332),
    mne_td: (330..332),
    mjs_td: 317,
    mns_td: 317,
    mnm_td: (249..258),
    defensive_spells: [
      "Elemental Targeting (425)",
      "Natural Colors (601)",
      "Mobility (618)"
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
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Inky necrotic core",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A dense cloud of flickering green pinpoints slowly revolves just above the ground, its mass spiked fitfully with outbursts of static electricity. In the next heartbeat, features, a tremendous torso, then massive arms knotted with thick muscles claim form from the hypnotic vapor. The naisirc moves lithely, belying its mighty proportions. As the naisirc stares at you, making a curious whispering noise, the spheres of glittering motes comprising its eyes send off crackles of furious viridian energy."
    ],
    arrival: [],
    flee: [],
    death: [
      "A naisirc fades into oblivion."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A naisirc glows with an eerie green light.",
      "A naisirc glows with a bright green light!"
    ],
    attacks: {
      attack: [
        "A naisirc charges at you!",
        "A naisirc lashes out at {target}!",
        "A naisirc tries to ensnare {target}!"
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
