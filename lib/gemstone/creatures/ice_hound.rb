{
  schema_version: 3,
  name: "ice hound",
  noun: "hound",
  url: "https://gswiki.play.net/ice_hound",
  picture: "",
  level: 24,
  family: "Canine",
  type: "Quadruped",
  undead: false,
  blood: nil,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 211,
  speed: nil,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Icemule Trail",
      uids: [4044002..4044019]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 192
      },
      {
        name: "Freezing ball of pure cold",
        as: 171
      }
    ],
    bolt_spells: [
      {
        name: "Major Cold (907)",
        as: 171
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (91..117),
    ranged: (96..111),
    bolt: (96..111),
    udf: (134..141),
    bar_td: nil,
    cle_td: 74,
    emp_td: 76,
    pal_td: (69..72),
    ran_td: nil,
    sor_td: 79,
    wiz_td: nil,
    mje_td: 81,
    mne_td: 81,
    mjs_td: 76,
    mns_td: 76,
    mnm_td: 72,
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
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "an ice hound ear",
    other: "essence of water",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The ice hound, protected by a long fur coat, is at home in the most frozen areas of the lands. One of the largest breeds of dog, its blue and silver fur blends well with the frozen lakes and rivers. A nasty bite and frosty breath make this canine a very formidable foe. A strange feature of this hound is that its eyes are completely white, giving its gaze a vacant, unfocused look."
    ],
    arrival: [
      "An ice hound arrives leaving puffs of ice crystal clouds in its wake."
    ],
    flee: [
      "An ice hound pads {direction}, a frosty mist puffing from {pronoun} nostrils."
    ],
    death: [
      "The ice hound lets out one last whimpering sigh of frosty mist and dies."
    ],
    decay: [
      "An ice hound decays into a compost of fur and fangs."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "An ice hound howls in rage as {pronoun} shakes off the stun.",
      "An ice hound howls silently in rage as {pronoun} shakes off the stun."
    ],
    attacks: {
      attack: [
        "An ice hound breathes an icy blast at you!"
      ],
      bite: [
        "An ice hound tries to bite you!"
      ],
      hurl: [
        "An ice hound hurls {weapon} at you!"
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
