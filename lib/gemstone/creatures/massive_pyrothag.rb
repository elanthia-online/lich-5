{
  schema_version: 3,
  name: "massive pyrothag",
  noun: "pyrothag",
  url: "https://gswiki.play.net/massive_pyrothag",
  picture: "",
  level: 58,
  family: "Pyrothag",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: "miniboss",
  otherclass: [
    "Living",
    "Magical",
    "Element-based"
  ],
  bcs: true,
  max_hp: 300,
  speed: 8,
  height: 10,
  size: "large",
  areas: [
    {
      name: "Volcano",
      uids: [3050017..3050036, 3052001..3052025]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Quarterstaff",
        as: 302
      },
      {
        name: "Stomp (attack)",
        as: 253
      },
      {
        name: "Pound (attack)",
        as: 283
      },
      {
        name: "Massive glaes club",
        as: (243..302)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Massive glaes club"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (466..492),
    ranged: (179..233),
    bolt: (179..233),
    udf: (336..417),
    bar_td: nil,
    cle_td: 231,
    emp_td: (213..228),
    pal_td: (189..208),
    ran_td: (177..186),
    sor_td: (229..238),
    wiz_td: nil,
    mje_td: nil,
    mne_td: (241..244),
    mjs_td: (219..228),
    mns_td: (191..219),
    mnm_td: (174..180),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a massive glaes club"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a pyrothag hide",
    other: "glowing violet mote of essence",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The pyrothag is a huge creature, towering over the tallest of giantmen. Scorched black by the heat of its environment, its thick skin protects it from blows and the hostile lava flows. The most striking thing aside from its size, is the lack of facial features. A smooth face matching its smooth black skin leaves one wondering how such a thing could have evolved."
    ],
    arrival: [
      "A massive pyrothag lumbers in!",
      "A sickly green massive pyrothag lumbers in!",
      "A massive pyrothag lumbers in, grumbling to itself!"
    ],
    flee: [
      "A massive pyrothag lumbers {direction}.",
      "A massive pyrothag rumbles loudly as it lumbers {direction}.",
      "A massive pyrothag crawls {direction}.",
      "A massive pyrothag lumbers {direction}, grumbling to {reflexive}!"
    ],
    death: [
      "The massive pyrothag vibrates violently one final time and then lies still.",
      "A massive pyrothag rumbles loudly as it leans to the left and topples to the ground with a loud *THUD*!",
      "The massive pyrothag falls to the ground and lies still.",
      "A massive pyrothag rumbles loudly as it leans to the right and topples to the ground with a loud *THUD*!",
      "A grotesque massive pyrothag rumbles loudly as it leans to the right and topples to the ground with a loud *THUD*!"
    ],
    decay: [],
    search: [],
    spell_prep: [],
    stun_break: [
      "A massive pyrothag shrugs off the attempt to put {pronoun} to sleep!"
    ],
    attacks: {
      attack: [
        "A massive pyrothag swings {weapon} at you!",
        "A massive pyrothag pounds at {target} with {pronoun} fist!",
        "A massive pyrothag swings a massive glaes club at {target}!"
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
