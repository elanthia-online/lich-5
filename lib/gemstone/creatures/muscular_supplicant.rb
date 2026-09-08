{
  schema_version: 3,
  name: "muscular supplicant",
  noun: "supplicant",
  url: "https://gswiki.play.net/muscular_supplicant",
  picture: "",
  level: 67,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Temple Wyneb",
      uids: [13300001..13300076, 13300080..13300080]
    },
    {
      name: "unmapped",
      uids: [13300077..13300079]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Flamberge",
        as: (273..342)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "MSTRIKE"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: 246,
    ranged: 319,
    bolt: 319,
    udf: (360..510),
    bar_td: 238,
    cle_td: (260..269),
    emp_td: (244..253),
    pal_td: (222..231),
    ran_td: (228..231),
    sor_td: (269..272),
    wiz_td: nil,
    mje_td: (283..285),
    mne_td: (283..285),
    mjs_td: (259..265),
    mns_td: (259..265),
    mnm_td: (197..206),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a dark steel flamberge"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Glowing violet essence dust",
      "glowing violet essence shard",
      "tiny golden seed"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Standing somewhere near average height for a human, the muscular supplicant is a lean frame of wiry muscle covered by scarred and dry skin. A great mop of greasy hair covers her eyes, twisted up in long braids. Intricate tattoos cover the exposed flesh, drawing unrecognizable patterns."
    ],
    arrival: [
      "A muscular supplicant just arrived.",
      "A muscular supplicant strides into the area!",
      "A muscular supplicant charges in, sweat beading on {pronoun} forehead!"
    ],
    flee: [
      "A muscular supplicant heads {direction}."
    ],
    death: [
      "A muscular supplicant spasms one last time and then dies.",
      "A muscular supplicant thrashes violently and then dies.",
      "A muscular supplicant dies and collapses to the floor.",
      "A muscular supplicant staggers, then falls to the floor and dies.",
      "With an ear-piercing cry of agony, the muscular supplicant dies.",
      "A muscular supplicant spasms in death and then goes still.",
      "A muscular supplicant moans in agony and then goes still.",
      "A muscular supplicant thrashes one last time and goes still."
    ],
    decay: [
      "A muscular supplicant crumbles to dust and blows away on the wind.",
      "A muscular supplicant suddenly dissolves into a puddle of viscous ooze.",
      "A muscular supplicant rapidly decays, flesh and bone crumbling to dust."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A muscular supplicant unleashes an earth-shattering bellow shaking off the stun!"
    ],
    attacks: {
      attack: [
        "A muscular supplicant swings {weapon} at you!"
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
