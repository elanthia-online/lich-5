{
  schema_version: 3,
  name: "crackling lightning fiend",
  noun: "fiend",
  url: "https://gswiki.play.net/crackling_lightning_fiend",
  picture: "",
  level: 79,
  family: "Elemental",
  type: "Elemental",
  undead: false,
  blood: nil,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 265,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Stormpeak",
      uids: [13150401..13150425]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Lightning Torrent(?)"
      },
      {
        name: "Crackling blue and golden spark",
        as: 317
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Jagged Jolt(?)"
      },
      {
        name: "Charge"
      },
      {
        name: "Ethereal Wave"
      },
      {
        name: "Ground Slam"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [],
    melee: (276..521),
    ranged: (241..385),
    bolt: (241..385),
    udf: (319..573),
    bar_td: nil,
    cle_td: (319..327),
    emp_td: (314..324),
    pal_td: (276..286),
    ran_td: (274..281),
    sor_td: (330..360),
    wiz_td: nil,
    mje_td: 379,
    mne_td: (352..382),
    mjs_td: (319..327),
    mns_td: (306..336),
    mnm_td: 276,
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Celerity (506)"
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
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [],
    arrival: [
      "A jolting charge in the air heralds the arrival of a crackling lightning fiend!",
      "A gust of wind and a flash of lightning herald the arrival of a stooped titan stormcaller as {pronoun} lumbers in."
    ],
    flee: [],
    death: [
      "With a last crackle and a burst of ozone, a crackling lightning fiend dissipates into nothingness."
    ],
    decay: [
      "With a white-hot corruscation of sparks, a crackling lightning fiend collapses into a buzzing tangle of glowing filaments."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A crackling lightning fiend launches a crackling blue and golden spark at you!",
        "A crackling lightning fiend raises a luminous hand and sends a bolt of blue and golden lightning streaking toward you!",
        "A crackling lightning fiend sends a crackling filament of energy toward you!",
        "A crackling lightning fiend roils and whirls, spitting sparks of electricity before sending a jagged bolt streaking toward you!"
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
