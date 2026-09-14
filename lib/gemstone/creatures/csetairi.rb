{
  schema_version: 3,
  name: "csetairi",
  noun: "csetairi",
  url: "https://gswiki.play.net/csetairi",
  picture: "",
  level: 81,
  family: "Csetairi",
  type: "Hybrid",
  undead: false,
  blood: true,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: nil,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Magical"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: 6,
  size: "large",
  areas: [
    {
      name: "The Rift",
      uids: [4567001..4567055]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Scimitar",
        as: (369..417)
      }
    ],
    bolt_spells: [
      {
        name: "Major Fire (908)",
        as: 352
      }
    ],
    warding_spells: [
      {
        name: "Web (118)",
        cs: 329
      },
      {
        name: "Bind (214)",
        cs: 329
      },
      {
        name: "Frenzy (216)",
        cs: 329
      }
    ],
    offensive_spells: [
      {
        name: "Bravery (211)"
      },
      {
        name: "Heroism (215)"
      }
    ],
    maneuvers: [
      {
        name: "Multi-strike"
      },
      {
        name: "Dispel"
      },
      {
        name: "Point"
      },
      {
        name: "Air Blast"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "5N",
    immunities: [],
    melee: (357..545),
    ranged: (269..385),
    bolt: (269..385),
    udf: (409..497),
    bar_td: (292..300),
    cle_td: (327..337),
    emp_td: (322..332),
    pal_td: (296..306),
    ran_td: (284..294),
    sor_td: (341..349),
    wiz_td: nil,
    mje_td: (360..365),
    mne_td: (360..365),
    mjs_td: (322..332),
    mns_td: (322..332),
    mnm_td: (310..319),
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)",
      "Lesser Shroud (120)",
      "Spirit Shield (202)",
      "Spell Shield (219)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a green-black spiked collar",
    "a green-black spiked helm",
    "a razor-sharp green-black scimitar"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "tiny golden seed",
      "n'ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [],
    arrival: [
      "A csetairi slithers in!"
    ],
    flee: [
      "A csetairi slithers {direction}."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A csetairi swings {weapon} at you!",
        "A csetairi points two of {pronoun} four hands at you!"
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
