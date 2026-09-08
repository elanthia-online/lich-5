{
  schema_version: 3,
  name: "animated slush",
  noun: "slush",
  url: "https://gswiki.play.net/animated_slush",
  picture: "",
  level: 54,
  family: "Elemental",
  type: "Elemental",
  undead: false,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: false,
  sympathy: true,
  muggable: nil,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Magical"
  ],
  bcs: true,
  max_hp: 260,
  speed: 10,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Gossamer Valley",
      uids: [13023013..13023054, 13023076..13023076]
    },
    {
      name: "unmapped",
      uids: [13023055..13023075]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound"
      },
      {
        name: "Icy appendage",
        as: (263..267)
      },
      {
        name: "Stream of water",
        as: 243
      }
    ],
    bolt_spells: [
      {
        name: "Minor Water (903)",
        as: 291
      }
    ],
    warding_spells: [
      {
        name: "Torment (718)",
        cs: 127
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Major Elemental Wave"
      },
      {
        name: "Slush wall"
      },
      {
        name: "Tail Swipe"
      },
      {
        name: "Ethereal Wave"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (225..298),
    ranged: (225..298),
    bolt: (225..298),
    udf: nil,
    bar_td: (185..197),
    cle_td: (202..208),
    emp_td: (200..208),
    pal_td: (171..180),
    ran_td: (171..180),
    sor_td: (206..212),
    wiz_td: nil,
    mje_td: (215..224),
    mne_td: (215..224),
    mjs_td: nil,
    mns_td: 200,
    mnm_td: (162..168),
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
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: nil,
    other: [
      "Gold Dust",
      "essence of water"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "An animated slush could easily be mistaken for a huge pile of snow that has partially melted then refrozen. It presents a squat, icy white cone ten feet wide at the base but only rising five feet high. The edges are slightly transparent and tinged a light blue, while the interior is dark, with portions seeming more solid than others. Rippling over the terrain, its exact motion indiscernible, the animated slush unerringly finds its prey, yet it displays no sensory glands of any type."
    ],
    arrival: [
      "An animated slush ripples in, its mass wobbling slightly as it arrives."
    ],
    flee: [],
    death: [
      "The animated slush falls to the ground dead, {pronoun} icy surface still pulsating with a blinding white hue."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "An animated slush glows brightly on the inside as tiny sparkles of light coalesce into a ball before brilliantly exploding outward towards you!",
      "An animated slush glows brightly for a split second!"
    ],
    attacks: {
      bolt: [
        "An animated slush hurls a stream of water at {target}!"
      ],
      attack: [
        "An animated slush flings an icy appendage at {target}!"
      ],
      hurl: [
        "An animated slush hurls {weapon} at you!"
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
