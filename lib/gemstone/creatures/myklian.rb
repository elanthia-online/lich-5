{
  schema_version: 3,
  name: "myklian",
  noun: "myklian",
  url: "https://gswiki.play.net/myklian",
  picture: "",
  level: 40,
  family: "Reptilian",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: nil,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 259,
  speed: 8,
  height: 2,
  size: "medium",
  areas: [
    {
      name: "The Broken Lands",
      uids: [94020..94026]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge",
        as: 251
      },
      {
        name: "Claw",
        as: 241
      },
      {
        name: "Stomp",
        as: 241
      },
      {
        name: "Foot",
        as: 241
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (418..425),
    ranged: (155..163),
    bolt: (155..163),
    udf: nil,
    bar_td: nil,
    cle_td: 181,
    emp_td: (171..172),
    pal_td: (128..138),
    ran_td: (127..132),
    sor_td: (132..237),
    wiz_td: nil,
    mje_td: (176..199),
    mne_td: (176..199),
    mjs_td: (153..202),
    mns_td: (153..202),
    mnm_td: (122..131),
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
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a (color) myklian scale",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The myklian is a fearsome beast, some form of large lizard or amphibian that usually travels on four legs, but sometimes stands upright on two legs. It has a short, stubby tail which is triangular in shape and covered with a luminescent, chitinous plate. Hard scales cover the rest of the beast's body, except for the soft underbelly. Bony spikes and knobs guard the beast's joints. The coloration of the myklian species ranges the entire spectrum, red, orange, yellow, green, blue and purple."
    ],
    arrival: [],
    flee: [
      "A red myklian heads {direction}.",
      "A blue myklian heads {direction}.",
      "A yellow myklian heads {direction}.",
      "An orange myklian heads {direction}.",
      "A young myklian heads {direction}."
    ],
    death: [
      "The blue myklian falls back into a heap and dies.",
      "The red myklian falls back into a heap and dies.",
      "The blue myklian hisses one last time and dies.",
      "The yellow myklian hisses one last time and dies.",
      "The young myklian hisses one last time and dies.",
      "The red myklian hisses one last time and dies.",
      "The young myklian falls back into a heap and dies.",
      "The yellow myklian falls back into a heap and dies.",
      "The orange myklian falls back into a heap and dies.",
      "A red myklian screeches loudly and slumps to the ground as a whitish-grey ichor oozes from its mangled left foreleg.",
      "The orange myklian hisses one last time and dies.",
      "A yellow myklian screeches loudly and slumps to the ground as a whitish-grey ichor oozes from its mangled left claw.",
      "A young myklian screeches loudly and slumps to the ground as a whitish-grey ichor oozes from its mangled right foreleg.",
      "A red myklian screeches loudly and slumps to the ground as a whitish-grey ichor oozes from its mangled right foreleg.",
      "A yellow myklian screeches loudly and slumps to the ground as a whitish-grey ichor oozes from its mangled right foreleg.",
      "A red myklian screeches loudly and slumps to the ground as a whitish-grey ichor oozes from its mangled right claw.",
      "An orange myklian screeches loudly and slumps to the ground as a whitish-grey ichor oozes from its mangled right claw.",
      "An orange myklian screeches loudly and slumps to the ground as a whitish-grey ichor oozes from its mangled left foreleg.",
      "The green myklian falls back into a heap and dies.",
      "A red myklian screeches loudly and slumps to the ground as a whitish-grey ichor oozes from its mangled left claw."
    ],
    decay: [
      "A blue myklian crumbles away into dust.",
      "A red myklian crumbles away into dust.",
      "A yellow myklian crumbles away into dust.",
      "A young myklian crumbles away into dust.",
      "An orange myklian crumbles away into dust.",
      "A green myklian crumbles away into dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A myklian charges at you!",
        "A myklian stomps at you with {pronoun} foot!"
      ],
      claw: [
        "A myklian claws at you!"
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
