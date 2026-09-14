{
  schema_version: 3,
  name: "glacial morph",
  noun: "morph",
  url: "https://gswiki.play.net/glacial_morph",
  picture: "",
  level: 56,
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
  speed: 13,
  height: 8,
  size: "large",
  areas: [
    {
      name: "Gossamer Valley",
      uids: [13023013..13023054]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound"
      },
      {
        name: "Ensnare"
      },
      {
        name: "Elongated block of ice",
        as: 310
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Ethereal Wave"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (224..472),
    ranged: (189..299),
    bolt: (189..299),
    udf: (289..466),
    bar_td: (188..194),
    cle_td: (204..222),
    emp_td: (205..208),
    pal_td: (181..190),
    ran_td: 178,
    sor_td: 221,
    wiz_td: nil,
    mje_td: (232..245),
    mne_td: (232..245),
    mjs_td: (178..208),
    mns_td: (178..208),
    mnm_td: (168..177),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: [
      "Hides when attacked"
    ]
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: nil,
    magic_items: nil,
    gems: false,
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
      "Chunks of ice appear to be held together by strands of organic material to form the rough outline of a bipedal creature. The chunks have no specific shape, and some are larger than others without direct relation to placement on glacial morph. Often the glacial morph draws in on itself, the chunks rearranging and reattaching to form a considerably different shape, and it seems to be able to change color at will to match its surroundings. The glacial morph peers out from two malevolent eyes set deeply in a 'head' of ice. Strangely, the head does not always appear to be on top of the torso."
    ],
    arrival: [
      "A glacial morph pounds in.",
      "A glacial morph pounds in, dropping small ice shards in {pronoun} wake."
    ],
    flee: [
      "A glacial morph pounds away headed {direction}.",
      "A glacial morph pounds south leaving small ice shards in {pronoun} wake."
    ],
    death: [
      "A glacial morph topples over, {pronoun} ice chunks banging against one another.",
      "The glacial morph falls to the ground dead, {pronoun} icy surface still pulsating with a blinding white hue."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A glacial morph swings {weapon} at you!",
        "A glacial morph flings a frozen appendage out that tries to grasp you but you dodge away from {pronoun} in time.",
        "A glacial morph pounds {pronoun} arms together, cracking and chipping the ice at the ends to form vicious spikes.",
        "The glacial morph attack slides right through {target} leaving no trace of a wound in {pronoun} path!",
        "A glacial morph swings an elongated block of ice at {target}!",
        "The glacial morph's attack slides right through {target} leaving no trace of a wound in {pronoun} path!",
        "A glacial morph heaves a block of ice at you!"
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
