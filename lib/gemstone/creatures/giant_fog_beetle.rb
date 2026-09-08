{
  schema_version: 3,
  name: "giant fog beetle",
  noun: "beetle",
  url: "https://gswiki.play.net/giant_fog_beetle",
  picture: "",
  level: 32,
  family: "Beetle",
  type: "Insect",
  undead: false,
  blood: nil,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: true,
  sleepable: nil,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 260,
  speed: 9,
  height: 2,
  size: "large",
  areas: [
    {
      name: "The Broken Lands",
      uids: [306016..306048]
    },
    {
      name: "Greymist Woods",
      uids: [3021001..3021016, 3022001..3022017]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pincer (attack)",
        as: 228
      },
      {
        name: "Pincer",
        as: (205..208)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Gas cloud"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (90..239),
    ranged: (85..141),
    bolt: (85..141),
    udf: (210..288),
    bar_td: 97,
    cle_td: (108..111),
    emp_td: (109..118),
    pal_td: (87..96),
    ran_td: (96..99),
    sor_td: 114,
    wiz_td: nil,
    mje_td: (114..119),
    mne_td: (114..119),
    mjs_td: (109..115),
    mns_td: (109..115),
    mnm_td: (93..96),
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
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a fog beetle carapace",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The giant fog beetle appears to be some sort of giant insect. It looks a little like some misshapen scorpion, but the tail on it is not as long as a scorpion's would be, and it flares like the tail of a lobster rather than ending in a poison sting. The segmented body is wide, supported by six short multi-jointed legs. A dull red chitinous shell covers most of its body, and a broad carapace protects its head. Two massive claws provide the creature with formidable weapons."
    ],
    arrival: [],
    flee: [
      "A giant fog beetle crawls {direction}.",
      "A giant fog beetle meanders {direction}."
    ],
    death: [
      "The giant fog beetle kicks a leg one last time and lies still.",
      "The giant fog beetle falls to the ground and lies twitching for a moment before going still."
    ],
    decay: [
      "A giant fog beetle's legs shrivel up beneath it as it decays into dust."
    ],
    search: [],
    spell_prep: [
      "A giant fog beetle hisses as {pronoun} slowly raises {reflexive} up on {pronoun} legs."
    ],
    attacks: {
      attack: [
        "A giant fog beetle snaps at you with {pronoun} pincer!"
      ],
      bite: [
        "A giant fog beetle snaps at you with {pronoun} pincer!",
        "A giant fog beetle snaps at {target} with {pronoun} pincer!"
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
